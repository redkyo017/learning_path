package week4

import (
	"strconv"
	"strings"
)

// 71. Simplify Path https://leetcode.com/problems/simplify-path/description/
func SimplifyPath(path string) string {
	if path == "" {
		return "/"
	}
	tokens := strings.Split(path, "/")
	simplifiedPath := []string{}
	for _, token := range tokens {
		if token == "." || token == "" {
			continue
		}
		if token == ".." {
			if len(simplifiedPath) > 0 {
				simplifiedPath = simplifiedPath[:len(simplifiedPath)-1]
			}
			continue
		}
		simplifiedPath = append(simplifiedPath, token)
	}
	if len(simplifiedPath) == 0 {
		return "/"
	}
	return "/" + strings.Join(simplifiedPath, "/")
}

// 150. Evaluate Reverse Polish Notation https://leetcode.com/problems/evaluate-reverse-polish-notation/description/
func EvalRPN(tokens []string) int {
	results := []int{}
	for i := 0; i < len(tokens); i++ {
		token, err := strconv.Atoi(tokens[i])
		if err == nil {
			results = append(results, token)
		} else {
			op1 := results[len(results)-2]
			op2 := results[len(results)-1]
			results = results[:len(results)-2]
			var number int
			switch tokens[i] {
			case "*":
				number = op1 * op2
			case "/":
				number = op1 / op2
			case "+":
				number = op1 + op2
			case "-":
				number = op1 - op2
			}
			results = append(results, number)
		}
	}
	return results[len(results)-1]
}
