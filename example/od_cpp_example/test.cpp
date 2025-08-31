#include <iostream>

int add_numbers(int x, int y) { return x + y; }

int main() {
  int a = 10;
  std::cout << "The value of a is: " << a << std::endl; // Breakpoint 1

  for (int i = 0; i < 5; ++i) {
    a = a + i;
    std::cout << "The current value of a is: " << a
              << std::endl; // Breakpoint 2
  }

  int b = 20;
  int c = add_numbers(a, b); // Breakpoint 3

  std::cout << "The final value of c is: " << c << std::endl; // Breakpoint 4

  return 0;
}
