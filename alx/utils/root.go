package utils

import (
  "bytes"
  "fmt"
  "os"
  "os/exec"
)

const (
  INBOX_DIR            = "0-inbox"
  SELF_DIR             = "2-self"
  SELF_REFLECTIONS_DIR = SELF_DIR + "/20-reflections"
)

type FileExistsError struct {
  FilePath string
}

func (e *FileExistsError) Error() string {
  return fmt.Sprintf("file %s already exists", e.FilePath)
}

type EnvVarNotFoundError struct {
  VariableName string
}

func (e *EnvVarNotFoundError) Error() string {
  return fmt.Sprintf("environment variable %s not found or set", e.VariableName)
}

// In most of the functions below, I don't really care about handling
// errors wherever they are called, if an error ever occurs, I'm fine
// with just exiting the program.

func GetDirOrExit(dir string) string {
  dir, err := GetEnv(dir)
  if err != nil {
    fmt.Printf("The %s environment variable is not set", dir)
    println(err.Error())
    os.Exit(1)
  }

  if exists, err := DirExists(dir); !exists {
    println(err.Error())
    os.Exit(1)
  }

  return dir
}

var currentEmployerOverride string

func SetCurrentEmployerOverride(employer string) {
  currentEmployerOverride = employer
}

func GetCurrentEmployerOrExit() string {
  // First check if we have an override set
  if currentEmployerOverride != "" {
    return currentEmployerOverride
  }

  // Otherwise, fall back to environment variable
  employer, err := GetEnv("CURRENT_EMPLOYER")
  if err != nil {
    fmt.Printf("The CURRENT_EMPLOYER environment variable is not set")
    println(err.Error())
    os.Exit(1)
  }
  return employer
}

func GetWorkDir() string {
  return "1-work/" + GetCurrentEmployerOrExit()
}

func GetEditorOrExit() string {
  editor, err := GetEnv("EDITOR")
  if err != nil {
    println(err.Error())
    os.Exit(1)
  }

  if exists, err := CommandExists(editor); !exists {
    fmt.Printf("The %s command does not exist ", editor)
    println(err.Error())
    os.Exit(1)
  }

  return editor
}

func ExecCmdOrExit(args ...string) {
  cmd := exec.Command(args[0], args[1:]...)
  cmd.Stdin = os.Stdin
  cmd.Stdout = os.Stdout
  cmd.Stderr = os.Stderr

  if err := cmd.Run(); err != nil {
    println(err.Error())
    os.Exit(1)
  }
}

func GetEnv(env string) (string, error) {
  if value, exists := os.LookupEnv(env); exists && value != "" {
    return value, nil
  } else {
    return "", &EnvVarNotFoundError{env}
  }
}

func DirExists(dir string) (bool, error) {
  if _, err := os.Stat(dir); os.IsNotExist(err) {
    return false, err
  }

  return true, nil
}

func FileExists(filepath string) bool {
  _, err := os.Stat(filepath)
  if err == nil {
    return true
  }

  if os.IsNotExist(err) {
    return false
  }

  return false
}

func CreateFile(filePath string, content bytes.Buffer) (bool, error) {
  if exists := FileExists(filePath); exists {
    return false, &FileExistsError{filePath}
  }

  file, err := os.Create(filePath)
  if err != nil {
    return false, err
  }
  defer file.Close()

  _, err = file.Write(content.Bytes())
  if err != nil {
    return false, err
  }

  return true, nil
}

func IsCommandNotFoundError(err error) bool {
  if exitError, ok := err.(*exec.ExitError); ok {
    // Exit status 127 typically indicates "command not found" on Unix-like systems
    return exitError.ExitCode() == 127
  }

  return false
}

func CommandExists(cmd string) (bool, error) {
  sysCmd := exec.Command("which", cmd)

  if err := sysCmd.Run(); err != nil {
    return false, err
  } else {
    return true, nil
  }
}

func FileCreatedFromEditor() bool {
  // Variable set in my Nvim config
  if inEditor, _ := GetEnv("WITHIN_EDITOR"); inEditor == "1" {
    return true
  }

  return false
}

func OpenNoteInEditorOrExit(editor, brainDir, relativeFilePath string) {
  if FileCreatedFromEditor() {
    nvimServer := os.Getenv("NVIM_SERVER")
    cmd := exec.Command("nvim", "--server", nvimServer, "--remote", relativeFilePath)
    if err := cmd.Start(); err != nil {
      println(err.Error())
      os.Exit(1)
    }
  } else {
    ExecCmdOrExit(editor, "-c", "cd "+brainDir, "-c", "e "+relativeFilePath, "-c", "normal 3j")
  }
}
