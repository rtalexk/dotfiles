package cmd

import (
  "alx/cmd/worktree"

  "github.com/spf13/cobra"
)

var worktreeCmd = &cobra.Command{
  Use:     "worktree",
  Aliases: []string{"wt"},
  Short:   "Manage git worktrees and tmux sessions",
}

func init() {
  rootCmd.AddCommand(worktreeCmd)
  worktreeCmd.AddCommand(worktree.AddCmd)
  worktreeCmd.AddCommand(worktree.RemoveCmd)
  worktreeCmd.AddCommand(worktree.ListCmd)
  worktreeCmd.AddCommand(worktree.ProjectCmd)
}
