package cmd

import (
	"alx/utils"
	"fmt"
	"os"
	"os/exec"

	"github.com/spf13/cobra"
)

// todoCmd represents the todo command
var todoCmd = &cobra.Command{
	Use:   "todo",
	Short: "Open Brain in the TODO list.",
	Run: func(cmd *cobra.Command, args []string) {
		brainDir, brainErr := utils.GetEnv("BRAIN")

		if brainErr != nil {
			println("The BRAIN environment variable is not set")
			println(brainErr.Error())
			os.Exit(1)
		}

		if exists, err := utils.DirExists(brainDir); !exists {
			println(err.Error())
			os.Exit(1)
		}

		editor, editorErr := utils.GetEnv("EDITOR")

		if editorErr != nil {
			println(editorErr.Error())
			os.Exit(1)
		}

		if exists, err := utils.CommandExists(editor); !exists {
			fmt.Printf("The %s command does not exist ", editor)
			println(err.Error())
			os.Exit(1)
		}

		sysCmd := exec.Command(editor, "-c", "cd "+brainDir, "-c", "e 2-self/todos.md")
		sysCmd.Stdin = os.Stdin
		sysCmd.Stdout = os.Stdout
		sysCmd.Stderr = os.Stderr

		if err := sysCmd.Run(); err != nil {
			println("Failed to open the editor")
			println(err.Error())
			os.Exit(1)
		}
	},
}

func init() {
	rootCmd.AddCommand(todoCmd)
}
