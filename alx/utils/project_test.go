package utils_test

import (
  "os"
  "os/exec"
  "path/filepath"
  "testing"

  "alx/utils"
)

func TestFindProjectRoot_FromProjectRoot(t *testing.T) {
  // Create a temp dir with a .bare subdir that is a valid git bare repo
  tmp := t.TempDir()
  bare := filepath.Join(tmp, ".bare")
  if err := os.MkdirAll(bare, 0755); err != nil {
    t.Fatal(err)
  }
  // Init a bare repo at .bare
  if err := runCmd(tmp, "git", "init", "--bare", ".bare"); err != nil {
    t.Fatalf("git init --bare: %v", err)
  }

  // Change into the project root
  orig, _ := os.Getwd()
  defer os.Chdir(orig)
  os.Chdir(tmp)

  root, err := utils.FindProjectRoot()
  if err != nil {
    t.Fatalf("unexpected error: %v", err)
  }
  realTmp, err := filepath.EvalSymlinks(tmp)
  if err != nil {
    t.Fatal(err)
  }
  if root != realTmp {
    t.Errorf("expected %s, got %s", realTmp, root)
  }
}

func TestFindProjectRoot_NotInProject(t *testing.T) {
  tmp := t.TempDir() // plain directory, no .bare, no git

  orig, _ := os.Getwd()
  defer os.Chdir(orig)
  os.Chdir(tmp)

  _, err := utils.FindProjectRoot()
  if err == nil {
    t.Fatal("expected error, got nil")
  }
}

// helper
func runCmd(dir string, name string, args ...string) error {
  cmd := exec.Command(name, args...)
  cmd.Dir = dir
  return cmd.Run()
}
