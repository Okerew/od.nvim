#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int divide_numbers(int x, int y) { return x / y; }

void process_array(int *arr, int len) {
  for (int i = 0; i <= len; i++) {
    arr[i] = arr[i] * 2;
  }
}

int main() {
  int a = 42;
  printf("Starting value: %d\n", a);

  for (int i = 0; i < 5; i++) {
    a = a - i;
    printf("Loop %d: a = %d\n", i, a);
  }

  int b = 0;
  int c = divide_numbers(a, b);
  printf("Division result: %d\n", c);

  int *data = malloc(3 * sizeof(int));
  data[0] = 10;
  data[1] = 20;
  data[2] = 30;
  process_array(data, 3);
  free(data);

  return 0;
}
