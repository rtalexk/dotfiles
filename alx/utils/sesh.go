package utils

import (
  "fmt"
  "os"
  "path/filepath"
  "strings"
)

type SeshSession struct {
  Name           string
  Path           string
  StartupCommand string
}

func SeshConfigPath() string {
  xdg := os.Getenv("XDG_CONFIG_HOME")
  if xdg == "" {
    home, _ := os.UserHomeDir()
    xdg = filepath.Join(home, ".config")
  }
  return filepath.Join(xdg, "sesh", "sesh.toml")
}

func AppendSeshSession(configPath string, session SeshSession) error {
  f, err := os.OpenFile(configPath, os.O_APPEND|os.O_WRONLY|os.O_CREATE, 0644)
  if err != nil {
    return err
  }
  defer f.Close()

  entry := fmt.Sprintf("\n[[session]]\nname = %q\npath = %q\n", session.Name, session.Path)
  if session.StartupCommand != "" {
    entry += fmt.Sprintf("startup_command = %q\n", session.StartupCommand)
  }
  _, err = f.WriteString(entry)
  return err
}

// RemoveSeshSession removes the [[session]] block with the given name.
// Uses line-based manipulation to preserve the file's existing formatting.
func RemoveSeshSession(configPath, name string) error {
  data, err := os.ReadFile(configPath)
  if err != nil {
    return err
  }

  lines := strings.Split(string(data), "\n")

  // Group lines into blocks separated by blank lines
  var blocks [][]string
  var cur []string
  for _, line := range lines {
    if strings.TrimSpace(line) == "" {
      if len(cur) > 0 {
        blocks = append(blocks, cur)
        cur = nil
      }
    } else {
      cur = append(cur, line)
    }
  }
  if len(cur) > 0 {
    blocks = append(blocks, cur)
  }

  target := fmt.Sprintf(`name = %q`, name)
  var kept [][]string
  for _, block := range blocks {
    matched := false
    for _, line := range block {
      if strings.TrimSpace(line) == target {
        matched = true
        break
      }
    }
    if !matched {
      kept = append(kept, block)
    }
  }

  if len(kept) == len(blocks) {
    return nil
  }

  var parts []string
  for _, block := range kept {
    parts = append(parts, strings.Join(block, "\n"))
  }
  result := strings.Join(parts, "\n\n") + "\n"
  return os.WriteFile(configPath, []byte(result), 0644)
}
