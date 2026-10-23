package main

/*
#ifndef DAWN_CUSTOM_VALUE
#error DAWN_CUSTOM_VALUE was not provided by CGO_CFLAGS
#endif
static int custom_value(void) { return DAWN_CUSTOM_VALUE; }
*/
import "C"

import "fmt"

func main() { fmt.Println(C.custom_value()) }
