package cmd

import (
  "alx/utils"

  "github.com/spf13/cobra"
)

var dotfCmd = &cobra.Command{
  Use:   "dotf",
  Short: "Open dotfiles",
  Long:  "Open $EDITOR app in the $DOTFILES directory.",
  Run: func(cmd *cobra.Command, args []string) {
    dotfilesDir := utils.GetDirOrExit("DOTFILES")
    editor := utils.GetEditorOrExit()
    utils.ExecCmdOrExit(editor, "-c", "cd "+dotfilesDir)
  },
}

func init() {
  rootCmd.AddCommand(dotfCmd)
}
