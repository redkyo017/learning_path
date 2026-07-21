package main

import (
	"fmt"

	"github.com/yourname/golang-mastery/phase2-rest/internal/middleware"
)

func main() {
	token, err := middleware.GenerateToken("user1")
	if err != nil {
		panic(err)
	}
	fmt.Println(token)
}
