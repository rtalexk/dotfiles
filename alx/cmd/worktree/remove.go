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
var fuzzyFlag bool

var errCancelled = fmt.Errorf("cancelled")

var RemoveCmd = &cobra.Command{
  Use:     "remove <name>",
  Aliases: []string{"rm"},
  Short:   "Remove a worktree and its tmux session",
  Args: func(cmd *cobra.Command, args []string) error {
    fuzzy, _ := cmd.Flags().GetBool("fuzzy")
    if fuzzy {
      return cobra.NoArgs(cmd, args)
    }
    return cobra.ExactArgs(1)(cmd, args)
  },
  RunE: runRemove,
}

func init() {
  RemoveCmd.Flags().BoolVarP(&forceFlag, "force", "f", false, "Force delete even if branch is unmerged or worktree has untracked/modified files")
  RemoveCmd.Flags().BoolVar(&fuzzyFlag, "fuzzy", false, "Pick worktree interactively with fzf")
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
  if fuzzyFlag {
    path, err = pickWorktree(bareDir, root)
    if err != nil {
      if err == errCancelled {
        return nil
      }
      return err
    }
  } else {
    path = args[0]
  }

  // Look up branch from worktree path
  branch, err := worktreeBranch(bareDir, filepath.Join(root, path))
  if err != nil {
    return err
  }

  sessionName := project.SessionName(path)

  forceDelete := forceFlag
  if !forceFlag {
    merged, err := isMerged(bareDir, branch)
    if err != nil {
      return err
    }
    dirtyFiles, err := getDirtyFiles(filepath.Join(root, path))
    if err != nil {
      return err
    }

    needsForce := !merged || len(dirtyFiles) > 0
    if needsForce {
      if !merged {
        fmt.Printf("Branch '%s' is not fully merged.\n", branch)
      }
      if len(dirtyFiles) > 0 {
        fmt.Printf("The worktree contains modified or untracked files:\n")
        for _, f := range dirtyFiles {
          fmt.Printf("  %s\n", f)
        }
      }
      fmt.Printf("Delete branch '%s' and remove worktree? [y/N] ", branch)
      var response string
      fmt.Scanln(&response)
      if strings.ToLower(strings.TrimSpace(response)) != "y" {
        return fmt.Errorf("aborted")
      }
      forceDelete = true
    }
  }

  // Only switch away if we're currently inside the session being removed
  if cur, err := exec.Command("tmux", "display-message", "-p", "#S").Output(); err == nil {
    if strings.TrimSpace(string(cur)) == sessionName {
      exec.Command("tmux", "switch-client", "-l").Run()
    }
  }

  demuxRemoveCmd := exec.Command("demux", "session", "remove", "--name", sessionName)
  if err := demuxRemoveCmd.Run(); err != nil {
    fmt.Fprintf(os.Stderr, "warning: failed to remove demux session: %v\n", err)
  }

  // Remove worktree (use absolute path so git can locate it regardless of cwd)
  absPath := filepath.Join(root, path)
  wtRemoveArgs := []string{"-C", bareDir, "worktree", "remove"}
  if forceDelete {
    wtRemoveArgs = append(wtRemoveArgs, "--force")
  }
  wtRemoveArgs = append(wtRemoveArgs, absPath)
  rmCmd := exec.Command("git", wtRemoveArgs...)
  rmCmd.Stdout = os.Stdout
  rmCmd.Stderr = os.Stderr
  if err := rmCmd.Run(); err != nil {
    if !forceDelete {
      return fmt.Errorf("git worktree remove failed: %w", err)
    }
    // git worktree remove --force fails when the directory contains non-git files
    // (e.g. node_modules). Fall back to manual removal + prune.
    if removeErr := os.RemoveAll(absPath); removeErr != nil {
      return fmt.Errorf("failed to remove worktree directory: %w", removeErr)
    }
    pruneCmd := exec.Command("git", "-C", bareDir, "worktree", "prune")
    pruneCmd.Stdout = os.Stdout
    pruneCmd.Stderr = os.Stderr
    if pruneErr := pruneCmd.Run(); pruneErr != nil {
      return fmt.Errorf("git worktree prune failed: %w", pruneErr)
    }
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
  os.RemoveAll(absPath)

  fmt.Printf("removed worktree '%s', branch '%s', session '%s'\n", path, branch, sessionName)
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
    return "", errCancelled
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

func isMerged(bareDir, branch string) (bool, error) {
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
      return true, nil
    }
  }

  return false, nil
}

func getDirtyFiles(worktreePath string) ([]string, error) {
  out, err := exec.Command("git", "-C", worktreePath, "status", "--porcelain").Output()
  if err != nil {
    return nil, fmt.Errorf("failed to check worktree status: %w", err)
  }
  var files []string
  for _, line := range strings.Split(strings.TrimSpace(string(out)), "\n") {
    if line != "" {
      files = append(files, line)
    }
  }
  return files, nil
}
