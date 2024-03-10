package cmd

import (
	"alx/cmd/work"

	"github.com/spf13/cobra"
)

var workCmd = &cobra.Command{
	Use:   "work COMMAND",
	Short: "Manage work stuff",
}

func init() {
	rootCmd.AddCommand(workCmd)
	workCmd.AddCommand(work.NoteCmd)
	workCmd.AddCommand(work.TodoCmd)
}
