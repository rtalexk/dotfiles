package worktree

import (
  "alx/utils"
  "fmt"
  "os"
  "os/exec"
  "path/filepath"

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

  bareDir := filepath.Join(root, ".bare")
  defaultBranch := utils.DefaultBranch(bareDir, project.Config)

  worktrees, err := utils.ListWorktrees(bareDir, root, project)
  if err != nil {
    return err
  }

  sessionName := mainSessionName(project, worktrees, defaultBranch)
  connectCmd := exec.Command("demux", "session", "connect", sessionName)
  connectCmd.Stdin = os.Stdin
  connectCmd.Stdout = os.Stdout
  connectCmd.Stderr = os.Stderr
  return connectCmd.Run()
}

func mainSessionName(project *utils.Project, worktrees []utils.WorktreeInfo, defaultBranch string) string {
  for _, wt := range worktrees {
    if wt.Branch == defaultBranch {
      return project.SessionName(wt.Path)
    }
  }
  return project.SessionName(defaultBranch)
}
