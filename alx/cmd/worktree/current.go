package worktree

import (
	"alx/utils"
	"fmt"
	"os"
	"path/filepath"

	"github.com/spf13/cobra"
)

var (
	currentFlagJSON  bool
	currentFlagAlias bool
)

var CurrentCmd = &cobra.Command{
	Use:   "current",
	Short: "Print the worktree holding the current directory",
	Args:  cobra.NoArgs,
	RunE:  runCurrent,
}

func init() {
	CurrentCmd.Flags().BoolVar(&currentFlagJSON, "json", false, "Emit a JSON object instead of the name")
	CurrentCmd.Flags().BoolVarP(&currentFlagAlias, "alias", "a", false, "Prefix name with project alias (e.g. dotf-main)")
}

func runCurrent(cmd *cobra.Command, args []string) error {
	root, err := utils.FindProjectRoot()
	if err != nil {
		return err
	}

	project, err := utils.LoadProject(root)
	if err != nil {
		return err
	}

	bareDir := filepath.Join(root, ".bare")
	worktrees, err := utils.ListWorktrees(bareDir, root, project)
	if err != nil {
		return err
	}

	wt, err := resolveWorktree(worktrees, "", "")
	if err != nil {
		return err
	}

	if currentFlagJSON {
		record := newWorktreeRecord(wt, project, utils.DefaultBranch(bareDir, project.Config))
		return writeJSON(os.Stdout, record)
	}

	fmt.Println(wtName(wt, project, currentFlagAlias))
	return nil
}
