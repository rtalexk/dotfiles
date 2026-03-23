package worktree

import (
	"alx/utils"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strings"

	"github.com/spf13/cobra"
)

var projectForceFlag bool

var ProjectCmd = &cobra.Command{
	Use:   "project",
	Short: "Manage project.toml configuration",
}

var projectInitCmd = &cobra.Command{
	Use:   "init",
	Short: "Scaffold a commented project.toml with defaults",
	Args:  cobra.NoArgs,
	RunE:  runProjectInit,
}

var projectShowCmd = &cobra.Command{
	Use:   "show",
	Short: "Print the resolved project configuration",
	Args:  cobra.NoArgs,
	RunE:  runProjectShow,
}

func init() {
	projectInitCmd.Flags().BoolVarP(&projectForceFlag, "force", "f", false, "Overwrite existing project.toml")
	ProjectCmd.AddCommand(projectInitCmd)
	ProjectCmd.AddCommand(projectShowCmd)
}

const projectTOMLTemplate = `# alias defaults to the project root directory name
# alias = "myapp"

# on_create runs once when the worktree is first created (not forwarded to sesh)
# on_create defaults to setup.rb / setup.sh / setup if present
# on_create = "bin/setup"
# on_create = ["bundle install", "bin/setup", "bin/rails db:migrate"]

# copy_files = [".env", "config/master.key"]

# [sesh]
# extra sesh session fields forwarded verbatim
`

func runProjectInit(cmd *cobra.Command, args []string) error {
	root, err := utils.FindProjectRoot()
	if err != nil {
		return err
	}

	tomlPath := filepath.Join(root, "project.toml")
	if _, err := os.Stat(tomlPath); err == nil && !projectForceFlag {
		return fmt.Errorf("project.toml already exists; use --force to overwrite")
	}

	return os.WriteFile(tomlPath, []byte(projectTOMLTemplate), 0644)
}

func runProjectShow(cmd *cobra.Command, args []string) error {
	root, err := utils.FindProjectRoot()
	if err != nil {
		return err
	}

	tomlPath := filepath.Join(root, "project.toml")
	_, statErr := os.Stat(tomlPath)
	missing := errors.Is(statErr, fs.ErrNotExist)

	project, err := utils.LoadProject(root)
	if err != nil {
		return err
	}

	if missing {
		fmt.Println("# project.toml not found — showing defaults")
		fmt.Println()
	}

	cfg := project.Config
	var sb strings.Builder
	sb.WriteString(fmt.Sprintf("alias = %q\n", cfg.Alias))
	if len(cfg.OnCreate) == 1 {
		sb.WriteString(fmt.Sprintf("on_create = %q\n", cfg.OnCreate[0]))
	} else if len(cfg.OnCreate) > 1 {
		quoted := make([]string, len(cfg.OnCreate))
		for i, c := range cfg.OnCreate {
			quoted[i] = fmt.Sprintf("%q", c)
		}
		sb.WriteString(fmt.Sprintf("on_create = [%s]\n", strings.Join(quoted, ", ")))
	}
	if len(cfg.CopyFiles) > 0 {
		allSame := true
		for _, f := range cfg.CopyFiles {
			if f.From != f.To {
				allSame = false
				break
			}
		}
		if allSame {
			quoted := make([]string, len(cfg.CopyFiles))
			for i, f := range cfg.CopyFiles {
				quoted[i] = fmt.Sprintf("%q", f.From)
			}
			sb.WriteString(fmt.Sprintf("copy_files = [%s]\n", strings.Join(quoted, ", ")))
		} else {
			for _, f := range cfg.CopyFiles {
				sb.WriteString("\n[[copy_files]]\n")
				sb.WriteString(fmt.Sprintf("from = %q\n", f.From))
				if f.To != f.From {
					sb.WriteString(fmt.Sprintf("to = %q\n", f.To))
				}
			}
		}
	}
	fmt.Print(sb.String())
	return nil
}
