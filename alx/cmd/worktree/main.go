package worktree

import (
  "alx/utils"
  "fmt"
  "os"
  "os/exec"

  "github.com/spf13/cobra"
)

var MainCmd = &cobra.Command{
  Use:   "main",
  Short: "Connect to the main worktree session of the current project",
  Args:  cobra.NoArgs,
  RunE:  runMain,
}

func runMain(cmd *cobra.Command, args []string) error {
  root, err := utils.FindProjectRoot()
  if err != nil {
    fmt.Println("Not a .bare worktree project; nothing to connect to.")
    return nil
  }

  project, err := utils.LoadProject(root)
  if err != nil {
    return err
  }

  sessionName := project.SessionName("main")
  connectCmd := exec.Command("demux", "session", "connect", sessionName)
  connectCmd.Stdin = os.Stdin
  connectCmd.Stdout = os.Stdout
  connectCmd.Stderr = os.Stderr
  return connectCmd.Run()
}
