package main

import (
	"fmt"

	"golang.org/x/text/language"
)

// REACHABLE: this program actually CALLS ParseAcceptLanguage, the function
// flagged by CVE-2022-32149 / GO-2022-1059 (DoS on crafted Accept-Language).
func main() {
	tags, _, err := language.ParseAcceptLanguage("en-US,en;q=0.9,ko;q=0.8")
	if err != nil {
		fmt.Println("parse error:", err)
		return
	}
	fmt.Println("parsed tags:", tags)
}
