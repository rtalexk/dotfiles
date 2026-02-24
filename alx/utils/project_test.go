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

func TestFindProjectRoot_FromInsideWorktree(t *testing.T) {
  tmp := t.TempDir()

  // Create a source repo with an initial commit so it has a branch
  source := filepath.Join(tmp, "source")
  if err := runCmd(tmp, "git", "init", source); err != nil {
    t.Fatalf("git init source: %v", err)
  }
  if err := runCmd(source, "git", "-c", "user.email=test@test.com", "-c", "user.name=Test", "commit", "--allow-empty", "-m", "init"); err != nil {
    t.Fatalf("git commit: %v", err)
  }

  // Clone it as a bare repo into <tmp>/.bare
  bare := filepath.Join(tmp, ".bare")
  if err := runCmd(tmp, "git", "clone", "--bare", source, bare); err != nil {
    t.Fatalf("git clone --bare: %v", err)
  }

  // Add a worktree from the bare repo
  main := filepath.Join(tmp, "main")
  if err := runCmd(bare, "git", "worktree", "add", main); err != nil {
    t.Fatalf("git worktree add: %v", err)
  }

  orig, _ := os.Getwd()
  defer os.Chdir(orig)
  if err := os.Chdir(main); err != nil {
    t.Fatalf("chdir: %v", err)
  }

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

func TestFindProjectRoot_RegularGitRepo_ReturnsError(t *testing.T) {
  tmp := t.TempDir()

  myrepo := filepath.Join(tmp, "myrepo")
  if err := runCmd(tmp, "git", "init", myrepo); err != nil {
    t.Fatalf("git init: %v", err)
  }
  if err := runCmd(myrepo, "git", "-c", "user.email=test@test.com", "-c", "user.name=Test", "commit", "--allow-empty", "-m", "init"); err != nil {
    t.Fatalf("git commit: %v", err)
  }

  orig, _ := os.Getwd()
  defer os.Chdir(orig)
  if err := os.Chdir(myrepo); err != nil {
    t.Fatalf("chdir: %v", err)
  }

  _, err := utils.FindProjectRoot()
  if err == nil {
    t.Fatal("expected error for regular git repo, got nil")
  }
}

// helper
func runCmd(dir string, name string, args ...string) error {
  cmd := exec.Command(name, args...)
  cmd.Dir = dir
  return cmd.Run()
}
