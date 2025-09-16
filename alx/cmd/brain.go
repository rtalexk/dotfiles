package cmd

import (
  "alx/utils"

  "github.com/spf13/cobra"
)

var brainCmd = &cobra.Command{
  Use:   "brain",
  Short: "Open notes",
  Long:  "Open $EDITOR app in the $BRAIN directory.",
  Run: func(cmd *cobra.Command, args []string) {
    brainDir := utils.GetDirOrExit("BRAIN")
    editor := utils.GetEditorOrExit()
    utils.ExecCmdOrExit(editor, "-c", "cd "+brainDir)
  },
}

func init() {
  rootCmd.AddCommand(brainCmd)
}
