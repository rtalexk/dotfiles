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

var AddCmd = &cobra.Command{
  Use:   "add <path> [branch]",
  Short: "Create a new worktree and tmux session",
  Args:  cobra.RangeArgs(1, 2),
  RunE:  runAdd,
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

  // Create branch + worktree
  gitArgs := resolveWorktreeAddArgs(bareDir, branch, worktreeDir)
  gitCmd := exec.Command("git", append([]string{"-C", bareDir}, gitArgs...)...)
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
    Extra:          project.Config.Sesh,
  }); err != nil {
    return fmt.Errorf("failed to update sesh config: %w", err)
  }

  // Create tmux session in detached mode (avoids sesh window-creation bug that
  // targets the active session instead of the new one)
  createCmd := exec.Command("tmux", "new-session", "-d", "-s", sessionName, "-c", worktreeDir)
  createCmd.Stdout = os.Stdout
  createCmd.Stderr = os.Stderr
  if err := createCmd.Run(); err != nil {
    return fmt.Errorf("worktree and sesh entry created; failed to create tmux session %q: %w", sessionName, err)
  }

  windows := sessionWindows(project.Config.Sesh)
  if len(windows) > 0 {
    windowDefs, _ := utils.LoadSeshWindowDefs(utils.SeshConfigPath())
    for i, winName := range windows {
      if i == 0 {
        exec.Command("tmux", "rename-window", "-t", sessionName+":0", winName).Run()
        if def, ok := windowDefs[winName]; ok && def.StartupCommand != "" {
          exec.Command("tmux", "send-keys", "-t", sessionName+":0", def.StartupCommand, "Enter").Run()
        }
      } else {
        exec.Command("tmux", "new-window", "-t", sessionName, "-n", winName, "-c", worktreeDir).Run()
        if def, ok := windowDefs[winName]; ok && def.StartupCommand != "" {
          exec.Command("tmux", "send-keys", "-t", sessionName, def.StartupCommand, "Enter").Run()
        }
      }
    }
    // Run project startup command in a dedicated window so it doesn't block
    // the configured windows (it may take a while, e.g. npm install)
    if project.Config.StartupCommand != "" {
      exec.Command("tmux", "new-window", "-t", sessionName, "-c", worktreeDir).Run()
      exec.Command("tmux", "send-keys", "-t", sessionName, project.Config.StartupCommand, "Enter").Run()
    }
    // Return focus to the first configured window
    exec.Command("tmux", "select-window", "-t", sessionName+":0").Run()
  } else if project.Config.StartupCommand != "" {
    exec.Command("tmux", "send-keys", "-t", sessionName, project.Config.StartupCommand, "Enter").Run()
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
    return fmt.Errorf("worktree and sesh entry created; failed to attach to session %q: %w", sessionName, err)
  }
  return nil
}

// sessionWindows extracts the []string window list from a sesh extra map.
func sessionWindows(sesh map[string]interface{}) []string {
  if sesh == nil {
    return nil
  }
  ws, ok := sesh["windows"]
  if !ok {
    return nil
  }
  raw, ok := ws.([]interface{})
  if !ok {
    return nil
  }
  out := make([]string, 0, len(raw))
  for _, v := range raw {
    if s, ok := v.(string); ok {
      out = append(out, s)
    }
  }
  return out
}

func resolveWorktreeAddArgs(bareDir, branch, worktreeDir string) []string {
  if exec.Command("git", "-C", bareDir, "rev-parse", "--verify", "refs/heads/"+branch).Run() == nil {
    return []string{"worktree", "add", worktreeDir, branch}
  }
  if exec.Command("git", "-C", bareDir, "rev-parse", "--verify", "refs/remotes/origin/"+branch).Run() == nil {
    return []string{"worktree", "add", "--track", "-b", branch, worktreeDir, "origin/" + branch}
  }
  return []string{"worktree", "add", worktreeDir, "-b", branch}
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
