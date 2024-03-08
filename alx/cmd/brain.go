package cmd

import (
	"alx/utils"
	"fmt"
	"os"
	"os/exec"

	"github.com/spf13/cobra"
)

var brainCmd = &cobra.Command{
	Use:   "brain",
	Short: "Open notes",
	Long:  "Open $EDITOR app in the $BRAIN directory.",
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

		sysCmd := exec.Command(editor, "-c", "cd "+brainDir)
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
	rootCmd.AddCommand(brainCmd)
	// brainCmd.PersistentFlags().String("foo", "", "A help for foo")
	// brainCmd.Flags().BoolP("toggle", "t", false, "Help message for toggle") // Local flag
}
