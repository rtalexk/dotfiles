package cmd

import (
	"alx/utils"
	"fmt"
	"os"
	"os/exec"

	"github.com/spf13/cobra"
)

var dotfCmd = &cobra.Command{
	Use:   "dotf",
	Short: "Open dotfiles",
	Long:  "Open $EDITOR app in the $DOTFILES directory.",
	Run: func(cmd *cobra.Command, args []string) {
		dotfilesDir, err := utils.GetEnv("DOTFILES")
		if err != nil {
			println("The BRAIN environment variable is not set")
			println(err.Error())
			os.Exit(1)
		}

		if exists, err := utils.DirExists(dotfilesDir); !exists {
			println(err.Error())
			os.Exit(1)
		}

		editor, err := utils.GetEnv("EDITOR")
		if err != nil {
			println(err.Error())
			os.Exit(1)
		}

		if exists, err := utils.CommandExists(editor); !exists {
			fmt.Printf("The %s command does not exist ", editor)
			println(err.Error())
			os.Exit(1)
		}

		sysCmd := exec.Command(editor, "-c", "cd "+dotfilesDir)
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
	rootCmd.AddCommand(dotfCmd)
}
