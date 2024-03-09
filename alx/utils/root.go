package utils

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
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
