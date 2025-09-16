package cmd

import (
  "alx/cmd/work"

  "github.com/spf13/cobra"
)

var (
  employerFlag string
)

var workCmd = &cobra.Command{
  Use:   "work COMMAND",
  Short: "Manage work stuff",
  PersistentPreRun: func(cmd *cobra.Command, args []string) {
    work.SetEmployer(employerFlag)
  },
}

func init() {
  rootCmd.AddCommand(workCmd)
  workCmd.AddCommand(work.NoteCmd)
  workCmd.AddCommand(work.TodoCmd)

  workCmd.PersistentFlags().StringVarP(&employerFlag, "employer", "e", "", "Override current employer (fallback to CURRENT_EMPLOYER env var)")
}
