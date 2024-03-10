package note

import (
	"alx/utils"
	"fmt"
	"os"
	"os/exec"

	"github.com/spf13/cobra"
)

var QuoteCmd = &cobra.Command{
	Use:   "quote",
	Short: "Open quotes",
	Run: func(cmd *cobra.Command, args []string) {
		brainDir, err := utils.GetEnv("BRAIN")
		if err != nil {
			println("The BRAIN environment variable is not set")
			println(err.Error())
			os.Exit(1)
		}

		if exists, err := utils.DirExists(brainDir); !exists {
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

		// Open the editor in the BRAIN dir, open the quotes file and copy the template
		sysCmd := exec.Command(
			editor,
			"-c",
			"cd "+brainDir,
			"-c",
			"e 2-self/20-reflections/quotes.md",
			"-c",
			"normal 3gg^V6jyP7jww",
		)
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

func init() {}
