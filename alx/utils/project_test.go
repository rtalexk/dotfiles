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

func TestLoadProject_AllFieldsExplicit(t *testing.T) {
  tmp := t.TempDir()
  os.WriteFile(filepath.Join(tmp, "project.toml"), []byte(`
alias = "myapp"
on_create = "sesh_dev"
copy_files = [".env", "config/master.key"]
`), 0644)

  p, err := utils.LoadProject(tmp)
  if err != nil {
    t.Fatal(err)
  }
  if p.Config.Alias != "myapp" {
    t.Errorf("alias: got %q", p.Config.Alias)
  }
  if p.Config.OnCreate.Command() != "sesh_dev" {
    t.Errorf("startup_command: got %q", p.Config.OnCreate.Command())
  }
  if len(p.Config.CopyFiles) != 2 {
    t.Errorf("copy_files len: got %d", len(p.Config.CopyFiles))
  }
  if p.Config.CopyFiles[0].From != ".env" || p.Config.CopyFiles[0].To != ".env" {
    t.Errorf("copy_files[0]: got from=%q to=%q", p.Config.CopyFiles[0].From, p.Config.CopyFiles[0].To)
  }
  if p.Config.CopyFiles[1].From != "config/master.key" || p.Config.CopyFiles[1].To != "config/master.key" {
    t.Errorf("copy_files[1]: got from=%q to=%q", p.Config.CopyFiles[1].From, p.Config.CopyFiles[1].To)
  }
  if p.Root != tmp {
    t.Errorf("Root: expected %q, got %q", tmp, p.Root)
  }
}

func TestLoadProject_OnCreate_Multiple(t *testing.T) {
  tmp := t.TempDir()
  os.WriteFile(filepath.Join(tmp, "project.toml"), []byte(`
on_create = ["bundle install", "bin/setup", "bin/rails db:migrate"]
`), 0644)

  p, err := utils.LoadProject(tmp)
  if err != nil {
    t.Fatal(err)
  }
  want := "bundle install && bin/setup && bin/rails db:migrate"
  if p.Config.OnCreate.Command() != want {
    t.Errorf("got %q, want %q", p.Config.OnCreate.Command(), want)
  }
}

func TestLoadProject_CopyFiles_FromTo(t *testing.T) {
  tmp := t.TempDir()
  os.WriteFile(filepath.Join(tmp, "project.toml"), []byte(`
[[copy_files]]
from = "master.key"
to = "config/master.key"

[[copy_files]]
from = ".env"
`), 0644)

  p, err := utils.LoadProject(tmp)
  if err != nil {
    t.Fatal(err)
  }
  if len(p.Config.CopyFiles) != 2 {
    t.Fatalf("copy_files len: got %d", len(p.Config.CopyFiles))
  }
  if p.Config.CopyFiles[0].From != "master.key" || p.Config.CopyFiles[0].To != "config/master.key" {
    t.Errorf("copy_files[0]: got from=%q to=%q", p.Config.CopyFiles[0].From, p.Config.CopyFiles[0].To)
  }
  if p.Config.CopyFiles[1].From != ".env" || p.Config.CopyFiles[1].To != ".env" {
    t.Errorf("copy_files[1]: got from=%q to=%q", p.Config.CopyFiles[1].From, p.Config.CopyFiles[1].To)
  }
}

func TestLoadProject_NoAlias_FallsBackToDirName(t *testing.T) {
  tmp := t.TempDir()
  // no project.toml

  p, err := utils.LoadProject(tmp)
  if err != nil {
    t.Fatal(err)
  }
  if p.Config.Alias != filepath.Base(tmp) {
    t.Errorf("expected dir name %q, got %q", filepath.Base(tmp), p.Config.Alias)
  }
}

func TestLoadProject_StartupCommand_SetupSh(t *testing.T) {
  tmp := t.TempDir()
  os.WriteFile(filepath.Join(tmp, "setup.sh"), []byte("#!/bin/bash"), 0755)

  p, err := utils.LoadProject(tmp)
  if err != nil {
    t.Fatal(err)
  }
  if p.Config.OnCreate.Command() != "./setup.sh" {
    t.Errorf("expected ./setup.sh, got %q", p.Config.OnCreate.Command())
  }
}

func TestLoadProject_StartupCommand_Setup(t *testing.T) {
  tmp := t.TempDir()
  os.WriteFile(filepath.Join(tmp, "setup"), []byte("#!/bin/bash"), 0755)

  p, err := utils.LoadProject(tmp)
  if err != nil {
    t.Fatal(err)
  }
  if p.Config.OnCreate.Command() != "./setup" {
    t.Errorf("expected ./setup, got %q", p.Config.OnCreate.Command())
  }
}

func TestLoadProject_StartupCommand_SetupRb(t *testing.T) {
  tmp := t.TempDir()
  os.WriteFile(filepath.Join(tmp, "setup.rb"), []byte("# ruby"), 0644)

  p, err := utils.LoadProject(tmp)
  if err != nil {
    t.Fatal(err)
  }
  if p.Config.OnCreate.Command() != "./setup.rb" {
    t.Errorf("expected ./setup.rb, got %q", p.Config.OnCreate.Command())
  }
}

func TestLoadProject_StartupCommand_Precedence(t *testing.T) {
  tmp := t.TempDir()
  os.WriteFile(filepath.Join(tmp, "project.toml"), []byte(`on_create = "sesh_dev"`), 0644)
  os.WriteFile(filepath.Join(tmp, "setup.sh"), []byte(""), 0755)

  p, err := utils.LoadProject(tmp)
  if err != nil {
    t.Fatal(err)
  }
  if p.Config.OnCreate.Command() != "sesh_dev" {
    t.Errorf("expected sesh_dev, got %q", p.Config.OnCreate.Command())
  }
}

func TestLoadProject_NoStartupCommand(t *testing.T) {
  tmp := t.TempDir()

  p, err := utils.LoadProject(tmp)
  if err != nil {
    t.Fatal(err)
  }
  if len(p.Config.OnCreate) != 0 {
    t.Errorf("expected empty startup_command, got %q", p.Config.OnCreate.Command())
  }
}

func TestSessionName(t *testing.T) {
  tmp := t.TempDir()
  os.WriteFile(filepath.Join(tmp, "project.toml"), []byte(`alias = "up"`), 0644)
  p, _ := utils.LoadProject(tmp)

  got := p.SessionName("feature-1")
  if got != "up-feature-1" {
    t.Errorf("expected up-feature-1, got %q", got)
  }
}
