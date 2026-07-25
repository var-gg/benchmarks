package main

import (
	"fmt"

	"golang.org/x/text/language"
)

// UNREACHABLE: same vulnerable dependency (golang.org/x/text v0.3.7) is in the
// module graph, but this program only calls language.Make — the vulnerable
// ParseAcceptLanguage is never reached from main.
func main() {
	tag := language.Make("en-US")
	fmt.Println("tag:", tag)
}
