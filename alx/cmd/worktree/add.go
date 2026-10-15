package worktree

import (
  "alx/utils"
  "fmt"
  "io"
  "os"
  "os/exec"
  "path/filepath"
  "strings"

  "github.com/spf13/cobra"
)

var (
  addBase     string
  addDetached bool
  addIssue    int
  addPR       int
)

var AddCmd = &cobra.Command{
  Use:   "add [path] [branch]",
  Short: "Create a new worktree and tmux session",
  Args:  cobra.RangeArgs(0, 2),
  RunE:  runAdd,
}

func init() {
  AddCmd.Flags().StringVar(&addBase, "base", "", "base ref for the new branch ('@' = current branch)")
  AddCmd.Flags().BoolVarP(&addDetached, "detached", "d", false, "Leave the new session detached instead of switching to it")
  AddCmd.Flags().IntVar(&addIssue, "issue", 0, "Name the branch after GitHub issue N")
  AddCmd.Flags().IntVar(&addPR, "pr", 0, "Check out the head branch of GitHub pull request N")
}

func runAdd(cmd *cobra.Command, args []string) error {
  root, err := utils.FindProjectRoot()
  if err != nil {
    return err
  }

  project, err := utils.LoadProject(root)
  if err != nil {
    return err
  }

  bareDir := filepath.Join(root, ".bare")

  path, branch, err := resolveAddTarget(bareDir, args, addIssue, addPR)
  if err != nil {
    return err
  }

  if strings.Contains(path, "..") {
    return fmt.Errorf("path must not contain '..': %s", path)
  }

  worktreeDir := filepath.Join(root, path)

  base, err := resolveBase(addBase)
  if err != nil {
    return err
  }

  // Create branch + worktree
  gitArgs, err := resolveWorktreeAddArgs(bareDir, branch, worktreeDir, base)
  if err != nil {
    return err
  }
  gitCmd := exec.Command("git", append([]string{"-C", bareDir}, gitArgs...)...)
  gitCmd.Stdout = os.Stdout
  gitCmd.Stderr = os.Stderr
  if err := gitCmd.Run(); err != nil {
    return fmt.Errorf("git worktree add failed: %w", err)
  }

  // Copy files
  for _, f := range project.Config.CopyFiles {
    src := filepath.Join(root, f.From)
    dst := filepath.Join(worktreeDir, f.To)
    switch f.Strategy {
    case utils.StrategySymlink:
      if err := linkFile(src, dst); err != nil {
        fmt.Fprintf(os.Stderr, "warning: could not link %s: %v\n", f.From, err)
      }
    default:
      if err := copyFile(src, dst); err != nil {
        fmt.Fprintf(os.Stderr, "warning: could not copy %s: %v\n", f.From, err)
      }
    }
  }

  sessionName := project.SessionName(path)
  demuxArgs := []string{"session", "config-add",
    "--name", sessionName,
    "--group", project.Config.Alias,
    "--path", worktreeDir,
    "--worktree",
    "--private",
  }
  if len(project.Config.Demux.Windows) > 0 {
    demuxArgs = append(demuxArgs, "--windows", strings.Join(project.Config.Demux.Windows, ","))
  }
  demuxCmd := exec.Command("demux", demuxArgs...)
  demuxCmd.Stderr = os.Stderr
  if err := demuxCmd.Run(); err != nil {
    return fmt.Errorf("failed to update demux config: %w", err)
  }

  // Create tmux session in detached mode to avoid a window-creation bug that
  // targets the active session instead of the new one
  createCmd := exec.Command("tmux", "new-session", "-d", "-s", sessionName, "-c", worktreeDir)
  createCmd.Stdout = os.Stdout
  createCmd.Stderr = os.Stderr
  if err := createCmd.Run(); err != nil {
    return fmt.Errorf("worktree created; failed to create tmux session %q: %w", sessionName, err)
  }

  if len(project.Config.Demux.Windows) > 0 {
    exec.Command("demux", "session", "create-windows",
      "--session", sessionName,
      "--windows", strings.Join(project.Config.Demux.Windows, ","),
    ).Run()
    if len(project.Config.OnCreate) > 0 {
      exec.Command("tmux", "new-window", "-t", sessionName, "-c", worktreeDir).Run()
      exec.Command("tmux", "send-keys", "-t", sessionName, project.Config.OnCreate.Command(), "Enter").Run()
    }
  } else if len(project.Config.OnCreate) > 0 {
    exec.Command("tmux", "send-keys", "-t", sessionName, project.Config.OnCreate.Command(), "Enter").Run()
  }

  // Switch to / attach the session
  connectCmd := connectCommand(sessionName, addDetached, os.Getenv("TMUX") != "")
  if connectCmd == nil {
    fmt.Printf("session %s created (detached)\n", sessionName)
    return nil
  }
  if err := connectCmd.Run(); err != nil {
    return fmt.Errorf("worktree created; failed to attach to session %q: %w", sessionName, err)
  }
  return nil
}

func connectCommand(sessionName string, detached, insideTmux bool) *exec.Cmd {
  if detached {
    return nil
  }
  if insideTmux {
    return exec.Command("tmux", "switch-client", "-t", sessionName)
  }
  cmd := exec.Command("tmux", "attach-session", "-t", sessionName)
  cmd.Stdin = os.Stdin
  cmd.Stdout = os.Stdout
  cmd.Stderr = os.Stderr
  return cmd
}


func validateAddArgs(args []string, issue, pr int) error {
  switch {
  case issue != 0 && pr != 0:
    return fmt.Errorf("--issue and --pr are mutually exclusive")
  case issue < 0:
    return fmt.Errorf("--issue must be a positive number")
  case pr < 0:
    return fmt.Errorf("--pr must be a positive number")
  case issue == 0 && pr == 0 && len(args) == 0:
    return fmt.Errorf("a worktree path is required unless --issue or --pr is given")
  case (issue != 0 || pr != 0) && len(args) == 2:
    return fmt.Errorf("--issue and --pr name the branch themselves; pass at most a path")
  }
  return nil
}

// resolveAddTarget decides the worktree path and the branch, asking GitHub
// for the name when --issue or --pr is given.
func resolveAddTarget(bareDir string, args []string, issue, pr int) (string, string, error) {
  if err := validateAddArgs(args, issue, pr); err != nil {
    return "", "", err
  }

  if issue == 0 && pr == 0 {
    path := args[0]
    branch := path
    if len(args) == 2 {
      branch = args[1]
    }
    return path, branch, nil
  }

  var branch string
  if issue != 0 {
    info, err := fetchIssue(bareDir, issue)
    if err != nil {
      return "", "", err
    }
    branch = issueBranch(issue, info.Title)
  } else {
    info, err := fetchPullRequest(bareDir, pr)
    if err != nil {
      return "", "", err
    }
    branch = prBranch(info)
    if err := fetchPullRequestRef(bareDir, info, branch); err != nil {
      return "", "", err
    }
  }

  if len(args) == 1 {
    return args[0], branch, nil
  }
  return worktreePathFor(branch), branch, nil
}

func fetchPullRequestRef(bareDir string, info pullRequestInfo, branch string) error {
  fetch := exec.Command("git", "-C", bareDir, "fetch", "origin", prFetchRefspec(info, branch))
  fetch.Stdout = os.Stdout
  fetch.Stderr = os.Stderr
  if err := fetch.Run(); err != nil {
    return fmt.Errorf("failed to fetch pull request %d: %w", info.Number, err)
  }
  return nil
}

func resolveBase(base string) (string, error) {
  if base != "@" {
    return base, nil
  }
  out, err := exec.Command("git", "branch", "--show-current").Output()
  if err != nil {
    return "", fmt.Errorf("could not resolve current branch for --base @: %w", err)
  }
  current := strings.TrimSpace(string(out))
  if current == "" {
    return "", fmt.Errorf("could not resolve --base @: detached HEAD")
  }
  return current, nil
}

func resolveWorktreeAddArgs(bareDir, branch, worktreeDir, base string) ([]string, error) {
  if exec.Command("git", "-C", bareDir, "rev-parse", "--verify", "refs/heads/"+branch).Run() == nil {
    if base != "" {
      return nil, fmt.Errorf("--base only applies when creating a new branch; %q already exists", branch)
    }
    return []string{"worktree", "add", worktreeDir, branch}, nil
  }
  if exec.Command("git", "-C", bareDir, "rev-parse", "--verify", "refs/remotes/origin/"+branch).Run() == nil {
    if base != "" {
      return nil, fmt.Errorf("--base only applies when creating a new branch; %q already exists on origin", branch)
    }
    return []string{"worktree", "add", "--track", "-b", branch, worktreeDir, "origin/" + branch}, nil
  }
  args := []string{"worktree", "add", worktreeDir, "-b", branch}
  if base != "" {
    args = append(args, base)
  }
  return args, nil
}

func copyFile(src, dst string) error {
  info, err := os.Stat(src)
  if err != nil {
    return err
  }
  if info.IsDir() {
    return copyDir(src, dst, info)
  }

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

func linkFile(src, dst string) error {
  if _, err := os.Stat(src); err != nil {
    return err
  }

  if info, err := os.Lstat(dst); err == nil {
    if info.Mode()&os.ModeSymlink == 0 {
      return fmt.Errorf("%s already exists and is not a symlink", dst)
    }
    if err := os.Remove(dst); err != nil {
      return err
    }
  }

  if err := os.MkdirAll(filepath.Dir(dst), 0755); err != nil {
    return err
  }
  return os.Symlink(src, dst)
}

func copyDir(src, dst string, info os.FileInfo) error {
  if err := os.MkdirAll(dst, info.Mode().Perm()); err != nil {
    return err
  }
  entries, err := os.ReadDir(src)
  if err != nil {
    return err
  }
  for _, e := range entries {
    if err := copyFile(filepath.Join(src, e.Name()), filepath.Join(dst, e.Name())); err != nil {
      return err
    }
  }
  return nil
}
