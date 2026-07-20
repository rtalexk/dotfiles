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

var addBase string

var AddCmd = &cobra.Command{
  Use:   "add <path> [branch]",
  Short: "Create a new worktree and tmux session",
  Args:  cobra.RangeArgs(1, 2),
  RunE:  runAdd,
}

func init() {
  AddCmd.Flags().StringVar(&addBase, "base", "", "base ref for the new branch ('@' = current branch)")
}

func runAdd(cmd *cobra.Command, args []string) error {
  path := args[0]
  branch := path
  if len(args) == 2 {
    branch = args[1]
  }

  if strings.Contains(path, "..") {
    return fmt.Errorf("path must not contain '..': %s", path)
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
    if err := copyFile(src, dst); err != nil {
      fmt.Fprintf(os.Stderr, "warning: could not copy %s: %v\n", f.From, err)
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
  var connectCmd *exec.Cmd
  if os.Getenv("TMUX") != "" {
    connectCmd = exec.Command("tmux", "switch-client", "-t", sessionName)
  } else {
    connectCmd = exec.Command("tmux", "attach-session", "-t", sessionName)
    connectCmd.Stdin = os.Stdin
    connectCmd.Stdout = os.Stdout
    connectCmd.Stderr = os.Stderr
  }
  if err := connectCmd.Run(); err != nil {
    return fmt.Errorf("worktree created; failed to attach to session %q: %w", sessionName, err)
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
