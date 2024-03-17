package cmd

import (
	"alx/utils"

	"github.com/spf13/cobra"
)

// todoCmd represents the todo command
var todoCmd = &cobra.Command{
	Use:   "todo",
	Short: "Open Brain in the TODO list.",
	Run: func(cmd *cobra.Command, args []string) {
		brainDir := utils.GetDirOrExit("BRAIN")
		editor := utils.GetEditorOrExit()
		utils.ExecCmdOrExit(editor, "-c", "cd "+brainDir, "-c", "e 2-self/todos.md")
	},
}

func init() {
	rootCmd.AddCommand(todoCmd)
}
