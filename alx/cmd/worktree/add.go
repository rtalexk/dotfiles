package worktree

import "github.com/spf13/cobra"

var AddCmd = &cobra.Command{
  Use:   "add <branch> [path]",
  Short: "Create a new worktree and tmux session",
}
