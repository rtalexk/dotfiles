package utils

import (
  "errors"
  "fmt"
  "io/fs"
  "os"
  "os/exec"
  "path/filepath"
  "strings"

  "github.com/BurntSushi/toml"
)

var supportedStartupFiles = []string{"setup.rb", "setup.sh", "setup"}

type CopyFile struct {
  From string
  To   string
}

type CopyFileList []CopyFile

func (c *CopyFileList) UnmarshalTOML(data interface{}) error {
  switch arr := data.(type) {
  case []interface{}:
    // copy_files = ["...", ...]  — inline array of strings
    for _, item := range arr {
      switch v := item.(type) {
      case string:
        *c = append(*c, CopyFile{From: v, To: v})
      case map[string]interface{}:
        *c = append(*c, copyFileFromMap(v))
      default:
        return fmt.Errorf("copy_files entries must be strings or tables, got %T", item)
      }
    }
  case []map[string]interface{}:
    // [[copy_files]]  — array of tables
    for _, m := range arr {
      *c = append(*c, copyFileFromMap(m))
    }
  default:
    return fmt.Errorf("copy_files must be an array, got %T", data)
  }
  return nil
}

func copyFileFromMap(m map[string]interface{}) CopyFile {
  cf := CopyFile{}
  if from, ok := m["from"].(string); ok {
    cf.From = from
  }
  if to, ok := m["to"].(string); ok {
    cf.To = to
  }
  if cf.To == "" {
    cf.To = cf.From
  }
  return cf
}

type OnCreateList []string

func (o *OnCreateList) UnmarshalTOML(data interface{}) error {
  switch v := data.(type) {
  case string:
    *o = OnCreateList{v}
  case []interface{}:
    for _, item := range v {
      s, ok := item.(string)
      if !ok {
        return fmt.Errorf("on_create entries must be strings, got %T", item)
      }
      *o = append(*o, s)
    }
  default:
    return fmt.Errorf("on_create must be a string or array of strings, got %T", data)
  }
  return nil
}

func (o OnCreateList) Command() string {
  return strings.Join(o, " && ")
}

type DemuxConfig struct {
  Windows []string `toml:"windows"`
}

type ProjectConfig struct {
  Alias     string       `toml:"alias"`
  OnCreate  OnCreateList `toml:"on_create"`
  CopyFiles CopyFileList `toml:"copy_files"`
  Demux     DemuxConfig  `toml:"demux"`
}

type Project struct {
  Root   string
  Config ProjectConfig
}

func LoadProject(root string) (*Project, error) {
  var cfg ProjectConfig
  tomlPath := filepath.Join(root, "project.toml")
  if _, err := os.Stat(tomlPath); err != nil {
    if !errors.Is(err, fs.ErrNotExist) {
      return nil, fmt.Errorf("failed to stat project.toml: %w", err)
    }
  } else {
    if _, err := toml.DecodeFile(tomlPath, &cfg); err != nil {
      return nil, fmt.Errorf("failed to parse project.toml: %w", err)
    }
  }

  if cfg.Alias == "" {
    cfg.Alias = filepath.Base(root)
  }

  if len(cfg.OnCreate) == 0 {
    for _, name := range supportedStartupFiles {
      if _, err := os.Stat(filepath.Join(root, name)); err == nil {
        cfg.OnCreate = OnCreateList{"./" + name}
        break
      }
    }
  }

  return &Project{Root: root, Config: cfg}, nil
}

func (p *Project) SessionName(path string) string {
  return p.Config.Alias + "-" + path
}

// FindProjectRoot locates the bare-clone project root from the current
// working directory. Works from any depth: project root, worktree root,
// or nested inside a worktree.
func FindProjectRoot() (string, error) {
  // Case 1: inside a worktree — git-common-dir points to .bare
  cmd := exec.Command("git", "rev-parse", "--is-inside-work-tree")
  if cmd.Run() == nil {
    out, err := exec.Command("git", "rev-parse", "--git-common-dir").Output()
    if err != nil {
      return "", fmt.Errorf("failed to get git-common-dir: %w", err)
    }
    bareDir := strings.TrimSpace(string(out))
    abs, err := filepath.Abs(bareDir)
    if err != nil {
      return "", err
    }
    real, err := filepath.EvalSymlinks(filepath.Dir(abs))
    if err != nil {
      return "", err
    }
    if _, err := os.Stat(filepath.Join(real, ".bare")); err != nil {
      return "", fmt.Errorf("not inside a bare worktree project")
    }
    return real, nil
  }

  // Case 2: in the project root directory (contains .bare/)
  cwd, err := os.Getwd()
  if err != nil {
    return "", err
  }
  probe := exec.Command("git", "--git-dir=.bare", "rev-parse", "--git-dir")
  probe.Dir = cwd
  if probe.Run() == nil {
    real, err := filepath.EvalSymlinks(cwd)
    if err != nil {
      return "", err
    }
    return real, nil
  }

  return "", fmt.Errorf("not inside a bare worktree project")
}
