#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <termios.h>
#include <fcntl.h>
#include <moonbit.h>

static struct termios orig_termios;
static int raw_mode_enabled = 0;

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

// Write a string to stdout without newline and flush
MOONBIT_FFI_EXPORT
void moonbit_watchdog_print_flush(moonbit_bytes_t msg) {
  int32_t len = Moonbit_array_length(msg);
  fwrite(msg, 1, len, stdout);
  fflush(stdout);
  moonbit_decref(msg);
}

// Enable raw mode on stdin (no echo, no line buffering, non-blocking)
MOONBIT_FFI_EXPORT
void moonbit_watchdog_term_enable_raw(void) {
  if (raw_mode_enabled) return;
  tcgetattr(STDIN_FILENO, &orig_termios);
  struct termios raw = orig_termios;
  raw.c_lflag &= ~(ECHO | ICANON);
  raw.c_cc[VMIN] = 0;
  raw.c_cc[VTIME] = 0;
  tcsetattr(STDIN_FILENO, TCSANOW, &raw);
  raw_mode_enabled = 1;
}

// Restore original terminal settings
MOONBIT_FFI_EXPORT
void moonbit_watchdog_term_restore(void) {
  if (!raw_mode_enabled) return;
  tcsetattr(STDIN_FILENO, TCSANOW, &orig_termios);
  raw_mode_enabled = 0;
}

// Non-blocking read of a single byte from stdin. Returns -1 if no input.
MOONBIT_FFI_EXPORT
int32_t moonbit_watchdog_read_key(void) {
  unsigned char c;
  if (read(STDIN_FILENO, &c, 1) == 1) {
    return (int32_t)c;
  }
  return -1;
}
