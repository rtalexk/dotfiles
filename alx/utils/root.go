package utils

import (
	"fmt"
	"os"
	"os/exec"
)

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
