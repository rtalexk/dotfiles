package work

import (
	"alx/utils"

	"github.com/spf13/cobra"
)

// todoCmd represents the todo command
var TodoCmd = &cobra.Command{
	Use:   "todo",
	Short: "Open Brain in the work's TODO list.",
	Run: func(cmd *cobra.Command, args []string) {
		brainDir := utils.GetDirOrExit("BRAIN")
		editor := utils.GetEditorOrExit()
		utils.ExecCmdOrExit(editor, "-c", "cd "+brainDir, "-c", "e 1-work/nuvo/todos.md")
	},
}

func init() {
}
