package utils_test

import (
  "os"
  "path/filepath"
  "strings"
  "testing"

  "alx/utils"
)

const sampleSesh = `[[session]]
name = "dotf"
path = "/Users/rtalex/com.github/dotfiles"
startup_command = "sesh_vim"

[[session]]
name = "brain"
path = "/Users/rtalex/Documents/Notes"
startup_command = "sesh_brain"
`

func TestAppendSeshSession_WithStartupCommand(t *testing.T) {
  f := tmpSesh(t, sampleSesh)

  err := utils.AppendSeshSession(f, utils.SeshSession{
    Name:           "myapp-feature-1",
    Path:           "/projects/myapp/feature-1",
    StartupCommand: "sesh_dev",
  })
  if err != nil {
    t.Fatal(err)
  }

  data, _ := os.ReadFile(f)
  content := string(data)
  if !strings.Contains(content, `name = "myapp-feature-1"`) {
    t.Error("missing name")
  }
  if !strings.Contains(content, `path = "/projects/myapp/feature-1"`) {
    t.Error("missing path")
  }
  if !strings.Contains(content, `startup_command = "sesh_dev"`) {
    t.Error("missing startup_command")
  }
}

func TestAppendSeshSession_WithoutStartupCommand(t *testing.T) {
  f := tmpSesh(t, sampleSesh)

  err := utils.AppendSeshSession(f, utils.SeshSession{
    Name: "myapp-feature-1",
    Path: "/projects/myapp/feature-1",
  })
  if err != nil {
    t.Fatal(err)
  }

  data, _ := os.ReadFile(f)
  content := string(data)
  // Original has 2 startup_command lines; new block should add 0 more
  count := strings.Count(content, "startup_command")
  if count != 2 {
    t.Errorf("expected 2 startup_command lines (originals only), got %d", count)
  }
}

func TestRemoveSeshSession_RemovesMatchingBlock(t *testing.T) {
  f := tmpSesh(t, sampleSesh)

  err := utils.RemoveSeshSession(f, "brain")
  if err != nil {
    t.Fatal(err)
  }

  data, _ := os.ReadFile(f)
  content := string(data)
  if strings.Contains(content, `name = "brain"`) {
    t.Error("brain block should have been removed")
  }
  if !strings.Contains(content, `name = "dotf"`) {
    t.Error("dotf block should be preserved")
  }
}

func TestRemoveSeshSession_PreservesOtherBlocks(t *testing.T) {
  f := tmpSesh(t, sampleSesh)

  if err := utils.RemoveSeshSession(f, "dotf"); err != nil {
    t.Fatal(err)
  }

  data, _ := os.ReadFile(f)
  content := string(data)
  if strings.Contains(content, `name = "dotf"`) {
    t.Error("dotf should be removed")
  }
  if !strings.Contains(content, `name = "brain"`) {
    t.Error("brain should be preserved")
  }
}

func TestRemoveSeshSession_NotFound_NoChange(t *testing.T) {
  f := tmpSesh(t, sampleSesh)

  err := utils.RemoveSeshSession(f, "nonexistent")
  if err != nil {
    t.Fatal(err)
  }

  data, _ := os.ReadFile(f)
  if string(data) != sampleSesh {
    t.Error("file should be unchanged when session not found")
  }
}

func tmpSesh(t *testing.T, content string) string {
  t.Helper()
  f := filepath.Join(t.TempDir(), "sesh.toml")
  os.WriteFile(f, []byte(content), 0644)
  return f
}
