#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <moonbit.h>

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
