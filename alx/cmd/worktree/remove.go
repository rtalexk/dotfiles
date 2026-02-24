package worktree

import "github.com/spf13/cobra"

var RemoveCmd = &cobra.Command{
  Use:     "remove [path]",
  Aliases: []string{"rm"},
  Short:   "Remove a worktree and its tmux session",
}
