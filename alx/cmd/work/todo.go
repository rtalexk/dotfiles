package work

import (
  "alx/utils"
  "fmt"

  "github.com/spf13/cobra"
)

// SetEmployer sets the current employer override in utils
func SetEmployer(employer string) {
  if employer != "" {
    utils.SetCurrentEmployerOverride(employer)
  }
}

// todoCmd represents the todo command
var TodoCmd = &cobra.Command{
  Use:   "todo",
  Short: "Open Brain in the work's TODO list.",
  Run: func(cmd *cobra.Command, args []string) {
    brainDir := utils.GetDirOrExit("BRAIN")
    editor := utils.GetEditorOrExit()
    editTodos := fmt.Sprintf("e %s/todos.md", utils.GetWorkDir())

    utils.ExecCmdOrExit(editor, "-c", "cd "+brainDir, "-c", editTodos)
  },
}

func init() {
}
