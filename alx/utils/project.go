package utils

import (
  "fmt"
  "os"
  "os/exec"
  "path/filepath"
  "strings"
)

// FindProjectRoot locates the bare-clone project root from the current
// working directory. Works from any depth: project root, worktree root,
// or nested inside a worktree.
func FindProjectRoot() (string, error) {
  // Case 1: inside a worktree — git-common-dir points to .bare
  cmd := exec.Command("git", "rev-parse", "--is-inside-work-tree")
  if cmd.Run() == nil {
    out, err := exec.Command("git", "rev-parse", "--git-common-dir").Output()
    if err != nil {
      return "", fmt.Errorf("failed to get git-common-dir: %w", err)
    }
    bareDir := strings.TrimSpace(string(out))
    abs, err := filepath.Abs(bareDir)
    if err != nil {
      return "", err
    }
    real, err := filepath.EvalSymlinks(filepath.Dir(abs))
    if err != nil {
      return "", err
    }
    return real, nil
  }

  // Case 2: in the project root directory (contains .bare/)
  cwd, err := os.Getwd()
  if err != nil {
    return "", err
  }
  probe := exec.Command("git", "--git-dir=.bare", "rev-parse", "--git-dir")
  probe.Dir = cwd
  if probe.Run() == nil {
    real, err := filepath.EvalSymlinks(cwd)
    if err != nil {
      return "", err
    }
    return real, nil
  }

  return "", fmt.Errorf("not inside a bare worktree project")
}
