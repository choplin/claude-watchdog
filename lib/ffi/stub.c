#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <moonbit.h>
#include <pwd.h>
#include <sys/types.h>

// Read all of stdin into a MoonBit Bytes value
MOONBIT_FFI_EXPORT
moonbit_bytes_t moonbit_watchdog_read_stdin(void) {
  size_t capacity = 4096;
  size_t length = 0;
  char *buf = (char *)malloc(capacity);
  if (!buf) {
    return moonbit_make_bytes(0, 0);
  }

  while (1) {
    size_t n = fread(buf + length, 1, capacity - length, stdin);
    length += n;
    if (n == 0) break;
    if (length == capacity) {
      capacity *= 2;
      char *newbuf = (char *)realloc(buf, capacity);
      if (!newbuf) {
        free(buf);
        return moonbit_make_bytes(0, 0);
      }
      buf = newbuf;
    }
  }

  moonbit_bytes_t result = moonbit_make_bytes(length, 0);
  memcpy(result, buf, length);
  free(buf);
  return result;
}

// Read an entire file into MoonBit Bytes. Returns empty bytes on error.
MOONBIT_FFI_EXPORT
moonbit_bytes_t moonbit_watchdog_read_file(moonbit_bytes_t path) {
  int32_t path_len = Moonbit_array_length(path);

  // Create null-terminated copy
  char *cpath = (char *)malloc(path_len + 1);
  if (!cpath) {
    moonbit_decref(path);
    return moonbit_make_bytes(0, 0);
  }
  memcpy(cpath, path, path_len);
  cpath[path_len] = '\0';
  moonbit_decref(path);

  FILE *f = fopen(cpath, "rb");
  free(cpath);
  if (!f) {
    return moonbit_make_bytes(0, 0);
  }

  fseek(f, 0, SEEK_END);
  long fsize = ftell(f);
  fseek(f, 0, SEEK_SET);

  if (fsize <= 0) {
    fclose(f);
    return moonbit_make_bytes(0, 0);
  }

  moonbit_bytes_t result = moonbit_make_bytes(fsize, 0);
  size_t read = fread(result, 1, fsize, f);
  fclose(f);

  if ((long)read != fsize) {
    // Partial read — still return what we got
    moonbit_bytes_t trimmed = moonbit_make_bytes(read, 0);
    memcpy(trimmed, result, read);
    moonbit_decref(result);
    return trimmed;
  }

  return result;
}

// Run a command and capture its stdout. Returns empty bytes on error.
MOONBIT_FFI_EXPORT
moonbit_bytes_t moonbit_watchdog_popen(moonbit_bytes_t command) {
  int32_t cmd_len = Moonbit_array_length(command);

  char *ccmd = (char *)malloc(cmd_len + 1);
  if (!ccmd) {
    moonbit_decref(command);
    return moonbit_make_bytes(0, 0);
  }
  memcpy(ccmd, command, cmd_len);
  ccmd[cmd_len] = '\0';
  moonbit_decref(command);

  FILE *fp = popen(ccmd, "r");
  free(ccmd);
  if (!fp) {
    return moonbit_make_bytes(0, 0);
  }

  size_t capacity = 4096;
  size_t length = 0;
  char *buf = (char *)malloc(capacity);
  if (!buf) {
    pclose(fp);
    return moonbit_make_bytes(0, 0);
  }

  while (1) {
    size_t n = fread(buf + length, 1, capacity - length, fp);
    length += n;
    if (n == 0) break;
    if (length == capacity) {
      capacity *= 2;
      char *newbuf = (char *)realloc(buf, capacity);
      if (!newbuf) {
        free(buf);
        pclose(fp);
        return moonbit_make_bytes(0, 0);
      }
      buf = newbuf;
    }
  }

  pclose(fp);

  moonbit_bytes_t result = moonbit_make_bytes(length, 0);
  memcpy(result, buf, length);
  free(buf);
  return result;
}

// Spawn a command in the background, detached (fire-and-forget).
// env_keys and env_vals are parallel arrays of key=value pairs encoded as Bytes.
// Each pair is separated by newline in a single Bytes buffer: "KEY=VAL\nKEY2=VAL2\n"
MOONBIT_FFI_EXPORT
void moonbit_watchdog_spawn_detached(moonbit_bytes_t command, moonbit_bytes_t env_pairs) {
  int32_t cmd_len = Moonbit_array_length(command);
  int32_t env_len = Moonbit_array_length(env_pairs);

  char *ccmd = (char *)malloc(cmd_len + 1);
  if (!ccmd) {
    moonbit_decref(command);
    moonbit_decref(env_pairs);
    return;
  }
  memcpy(ccmd, command, cmd_len);
  ccmd[cmd_len] = '\0';

  char *cenv = NULL;
  if (env_len > 0) {
    cenv = (char *)malloc(env_len + 1);
    if (cenv) {
      memcpy(cenv, env_pairs, env_len);
      cenv[env_len] = '\0';
    }
  }

  moonbit_decref(command);
  moonbit_decref(env_pairs);

  pid_t pid = fork();
  if (pid == 0) {
    // Child process
    // Set environment variables from pairs
    if (cenv) {
      char *line = cenv;
      while (*line) {
        char *nl = strchr(line, '\n');
        if (nl) *nl = '\0';
        if (*line) {
          putenv(line); // line is "KEY=VALUE"
        }
        if (!nl) break;
        line = nl + 1;
      }
    }

    // Redirect stdin/stdout/stderr to /dev/null
    freopen("/dev/null", "r", stdin);
    freopen("/dev/null", "w", stdout);
    freopen("/dev/null", "w", stderr);

    // Create new session (detach from parent)
    setsid();

    execl("/bin/sh", "sh", "-c", ccmd, (char *)NULL);
    _exit(127);
  }

  // Parent: don't wait
  free(ccmd);
  free(cenv);
}

// Check if a file descriptor is a terminal
MOONBIT_FFI_EXPORT
int32_t moonbit_watchdog_isatty(int32_t fd) {
  return isatty(fd) ? 1 : 0;
}

// Write a message to stderr
MOONBIT_FFI_EXPORT
void moonbit_watchdog_eprintln(moonbit_bytes_t msg) {
  int32_t len = Moonbit_array_length(msg);
  fwrite(msg, 1, len, stderr);
  fputc('\n', stderr);
  moonbit_decref(msg);
}

// Exit the process
MOONBIT_FFI_EXPORT
void moonbit_watchdog_exit(int32_t code) {
  exit(code);
}

// Get the user's home directory
MOONBIT_FFI_EXPORT
moonbit_bytes_t moonbit_watchdog_home_dir(void) {
  const char *home = getenv("HOME");
  if (!home) {
    struct passwd *pw = getpwuid(getuid());
    if (pw) {
      home = pw->pw_dir;
    }
  }
  if (!home) {
    return moonbit_make_bytes(0, 0);
  }
  int32_t len = strlen(home);
  moonbit_bytes_t result = moonbit_make_bytes(len, 0);
  memcpy(result, home, len);
  return result;
}
