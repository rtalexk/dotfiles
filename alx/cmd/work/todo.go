package work

import (
	"alx/utils"
	"fmt"

	"github.com/spf13/cobra"
)

// todoCmd represents the todo command
var TodoCmd = &cobra.Command{
	Use:   "todo",
	Short: "Open Brain in the work's TODO list.",
	Run: func(cmd *cobra.Command, args []string) {
		brainDir := utils.GetDirOrExit("BRAIN")
		editor := utils.GetEditorOrExit()
		editTodos := fmt.Sprintf("e %s/todos.md", utils.WORK_DIR)

		utils.ExecCmdOrExit(editor, "-c", "cd "+brainDir, "-c", editTodos)
	},
}

func init() {
}
