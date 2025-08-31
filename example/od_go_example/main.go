package main

import (
	"fmt"
	"main/greetings"
)

func main() {
	fmt.Println("About to panic...")
	slice := []int{1, 2, 3}
	x := 7 % 2
	if x == 0 {
		fmt.Println("7 is even")
	} else {
		fmt.Println("7 is odd")
	}
	greetings.Hello("Okerew")
	fmt.Println(slice[10]) // Panic: index out of range - line 10
}
