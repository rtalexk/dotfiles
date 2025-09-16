package cmd

import (
  "os"

  "github.com/spf13/cobra"
)

var rootCmd = &cobra.Command{
  Use:   "alx [COMMAND] [OPTIONS]",
  Short: "Set of personal commands to boost my productivity",
}

func Execute() {
  err := rootCmd.Execute()
  if err != nil {
    os.Exit(1)
  }
}

func init() {}
