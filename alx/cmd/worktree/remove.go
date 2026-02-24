package worktree

import (
  "alx/utils"
  "bufio"
  "fmt"
  "os"
  "os/exec"
  "path/filepath"
  "strings"

  "github.com/spf13/cobra"
)

var forceFlag bool

var RemoveCmd = &cobra.Command{
  Use:     "remove [path]",
  Aliases: []string{"rm"},
  Short:   "Remove a worktree and its tmux session",
  Args:    cobra.MaximumNArgs(1),
  RunE:    runRemove,
}

func init() {
  RemoveCmd.Flags().BoolVarP(&forceFlag, "force", "f", false, "Force delete even if branch is unmerged")
}

func runRemove(cmd *cobra.Command, args []string) error {
  root, err := utils.FindProjectRoot()
  if err != nil {
    return err
  }

  project, err := utils.LoadProject(root)
  if err != nil {
    return err
  }

  bareDir := filepath.Join(root, ".bare")

  // Resolve path
  var path string
  if len(args) == 1 {
    path = args[0]
  } else {
    path, err = pickWorktree(bareDir, root)
    if err != nil {
      return err
    }
  }

  // Look up branch from worktree path
  branch, err := worktreeBranch(bareDir, filepath.Join(root, path))
  if err != nil {
    return err
  }

  sessionName := project.SessionName(path)

  // Merge check
  forceDelete := forceFlag
  if !forceFlag {
    forceDelete, err = checkMerged(bareDir, branch)
    if err != nil {
      return err
    }
  }

  // Switch to previous tmux session before killing the current one
  exec.Command("tmux", "switch-client", "-l").Run()

  // Kill tmux session (detach-on-destroy off keeps us in tmux)
  exec.Command("tmux", "kill-session", "-t", sessionName).Run()

  // Remove sesh entry
  if err := utils.RemoveSeshSession(utils.SeshConfigPath(), sessionName); err != nil {
    fmt.Fprintf(os.Stderr, "warning: failed to update sesh config: %v\n", err)
  }

  // Remove worktree
  rmCmd := exec.Command("git", "-C", bareDir, "worktree", "remove", path)
  rmCmd.Stdout = os.Stdout
  rmCmd.Stderr = os.Stderr
  if err := rmCmd.Run(); err != nil {
    return fmt.Errorf("git worktree remove failed: %w", err)
  }

  // Delete branch
  branchFlag := "-d"
  if forceDelete {
    branchFlag = "-D"
  }
  branchCmd := exec.Command("git", "-C", bareDir, "branch", branchFlag, branch)
  branchCmd.Stdout = os.Stdout
  branchCmd.Stderr = os.Stderr
  if err := branchCmd.Run(); err != nil {
    return fmt.Errorf("git branch delete failed: %w", err)
  }

  // Remove directory if still present (git worktree remove may have cleaned it)
  os.RemoveAll(filepath.Join(root, path))

  return nil
}

func pickWorktree(bareDir, root string) (string, error) {
  out, err := exec.Command("git", "-C", bareDir, "worktree", "list").Output()
  if err != nil {
    return "", fmt.Errorf("failed to list worktrees: %w", err)
  }

  defaultBranch := "main"
  if refOut, err := exec.Command("git", "-C", bareDir, "symbolic-ref", "refs/remotes/origin/HEAD").Output(); err == nil {
    ref := strings.TrimSpace(string(refOut))
    parts := strings.Split(ref, "/")
    if len(parts) > 0 {
      defaultBranch = parts[len(parts)-1]
    }
  }

  var names []string
  scanner := bufio.NewScanner(strings.NewReader(string(out)))
  for scanner.Scan() {
    line := scanner.Text()
    if strings.Contains(line, "(bare)") {
      continue
    }
    fields := strings.Fields(line)
    if len(fields) == 0 {
      continue
    }
    lastField := fields[len(fields)-1]
    if strings.HasPrefix(lastField, "(HEAD") {
      continue
    }
    branch := strings.Trim(lastField, "[]")
    if branch == defaultBranch {
      continue
    }
    rel, err := filepath.Rel(root, fields[0])
    if err != nil {
      continue
    }
    names = append(names, rel)
  }

  if len(names) == 0 {
    return "", fmt.Errorf("no removable worktrees found")
  }

  fzf := exec.Command("fzf", "--prompt=worktree> ")
  fzf.Stdin = strings.NewReader(strings.Join(names, "\n"))
  fzf.Stderr = os.Stderr
  chosen, err := fzf.Output()
  if err != nil {
    return "", fmt.Errorf("fzf selection cancelled")
  }

  return strings.TrimSpace(string(chosen)), nil
}

func worktreeBranch(bareDir, worktreePath string) (string, error) {
  out, err := exec.Command("git", "-C", bareDir, "worktree", "list", "--porcelain").Output()
  if err != nil {
    return "", fmt.Errorf("failed to list worktrees: %w", err)
  }

  blocks := strings.Split(strings.TrimSpace(string(out)), "\n\n")
  for _, block := range blocks {
    lines := strings.Split(block, "\n")
    var wtPath, branchRef string
    for _, line := range lines {
      if strings.HasPrefix(line, "worktree ") {
        wtPath = strings.TrimPrefix(line, "worktree ")
      }
      if strings.HasPrefix(line, "branch ") {
        branchRef = strings.TrimPrefix(line, "branch ")
      }
    }
    if wtPath == worktreePath {
      if branchRef == "" {
        return "", fmt.Errorf("worktree %s is in detached HEAD state", worktreePath)
      }
      // branchRef = "refs/heads/feature-1"
      parts := strings.SplitN(branchRef, "/", 3)
      if len(parts) == 3 {
        return parts[2], nil
      }
      return branchRef, nil
    }
  }

  return "", fmt.Errorf("could not find branch for worktree path %s", worktreePath)
}

func checkMerged(bareDir, branch string) (bool, error) {
  defaultBranch := "main"
  if out, err := exec.Command("git", "-C", bareDir, "symbolic-ref", "refs/remotes/origin/HEAD").Output(); err == nil {
    ref := strings.TrimSpace(string(out))
    parts := strings.Split(ref, "/")
    if len(parts) > 0 {
      defaultBranch = parts[len(parts)-1]
    }
  }

  out, err := exec.Command("git", "-C", bareDir, "branch", "--merged", defaultBranch).Output()
  if err != nil {
    return false, fmt.Errorf("failed to check merged branches: %w", err)
  }

  for _, line := range strings.Split(string(out), "\n") {
    if strings.TrimSpace(strings.TrimPrefix(line, "* ")) == branch {
      return false, nil
    }
  }

  // Not merged — prompt
  fmt.Printf("error: The branch '%s' is not fully merged.\n", branch)
  fmt.Printf("If you are sure you want to delete it, re-run with --force.\n")
  fmt.Printf("Delete branch '%s'? [y/N] ", branch)

  var response string
  fmt.Scanln(&response)
  if strings.ToLower(strings.TrimSpace(response)) == "y" {
    return true, nil
  }

  return false, fmt.Errorf("aborted")
}
