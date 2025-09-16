package cmd

import (
  "alx/utils"
  "fmt"

  "github.com/spf13/cobra"
)

// todoCmd represents the todo command
var todoCmd = &cobra.Command{
  Use:   "todo",
  Short: "Open Brain in the TODO list.",
  Run: func(cmd *cobra.Command, args []string) {
    brainDir := utils.GetDirOrExit("BRAIN")
    editor := utils.GetEditorOrExit()
    editTodos := fmt.Sprintf("e %s/todos.md", utils.SELF_DIR)

    utils.ExecCmdOrExit(editor, "-c", "cd "+brainDir, "-c", editTodos)
  },
}

func init() {
  rootCmd.AddCommand(todoCmd)
}
