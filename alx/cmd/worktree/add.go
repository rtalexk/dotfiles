package worktree

import (
  "alx/utils"
  "fmt"
  "io"
  "os"
  "os/exec"
  "path/filepath"

  "github.com/spf13/cobra"
)

var AddCmd = &cobra.Command{
  Use:   "add <branch> [path]",
  Short: "Create a new worktree and tmux session",
  Args:  cobra.RangeArgs(1, 2),
  RunE:  runAdd,
}

func runAdd(cmd *cobra.Command, args []string) error {
  branch := args[0]
  path := branch
  if len(args) == 2 {
    path = args[1]
  }

  root, err := utils.FindProjectRoot()
  if err != nil {
    return err
  }

  project, err := utils.LoadProject(root)
  if err != nil {
    return err
  }

  bareDir := filepath.Join(root, ".bare")
  worktreeDir := filepath.Join(root, path)

  // Create branch + worktree
  gitCmd := exec.Command("git", "-C", bareDir, "worktree", "add", worktreeDir, "-b", branch)
  gitCmd.Stdout = os.Stdout
  gitCmd.Stderr = os.Stderr
  if err := gitCmd.Run(); err != nil {
    return fmt.Errorf("git worktree add failed: %w", err)
  }

  // Copy files
  for _, f := range project.Config.CopyFiles {
    src := filepath.Join(root, f)
    dst := filepath.Join(worktreeDir, f)
    if err := copyFile(src, dst); err != nil {
      fmt.Fprintf(os.Stderr, "warning: could not copy %s: %v\n", f, err)
    }
  }

  // Add sesh entry
  sessionName := project.SessionName(path)
  if err := utils.AppendSeshSession(utils.SeshConfigPath(), utils.SeshSession{
    Name:           sessionName,
    Path:           worktreeDir,
    StartupCommand: project.Config.StartupCommand,
  }); err != nil {
    return fmt.Errorf("failed to update sesh config: %w", err)
  }

  // Create + attach tmux session
  seshCmd := exec.Command("sesh", "connect", sessionName)
  seshCmd.Stdin = os.Stdin
  seshCmd.Stdout = os.Stdout
  seshCmd.Stderr = os.Stderr
  if err := seshCmd.Run(); err != nil {
    return fmt.Errorf("worktree and sesh entry created; failed to connect session %q: %w", sessionName, err)
  }
  return nil
}

func copyFile(src, dst string) error {
  in, err := os.Open(src)
  if err != nil {
    return err
  }
  defer in.Close()

  if err := os.MkdirAll(filepath.Dir(dst), 0755); err != nil {
    return err
  }

  out, err := os.Create(dst)
  if err != nil {
    return err
  }

  if _, err = io.Copy(out, in); err != nil {
    out.Close()
    return err
  }
  return out.Close()
}
