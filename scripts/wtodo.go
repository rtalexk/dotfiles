package main

import (
	"fmt"
	"io/fs"
	"os"
	"os/exec"
)

func main() {
	brainDir := os.Getenv("BRAIN")

	todosFile := "1-work/nuvo/todos.md"
	todosPath := fmt.Sprintf("%s/%s", brainDir, todosFile)

	// Check if the file exists
	if _, err := os.Stat(todosPath); os.IsNotExist(err) {
		if err := os.WriteFile(todosPath, []byte("# To-Do List\n\n"), fs.FileMode(0644)); err != nil {
			fmt.Printf("Error creating todos file: %v\n", err)
			os.Exit(1)
		}
	}

	cmd := exec.Command("nvim", "-c", "e "+todosPath)
	cmd.Stdout = os.Stdout
	cmd.Stdin = os.Stdin
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		fmt.Printf("Error running nvim: %v\n", err)
		os.Exit(1)
	}
}
