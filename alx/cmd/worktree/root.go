package worktree

import (
	"alx/utils"
	"fmt"
	"path/filepath"

	"github.com/spf13/cobra"
)

var RootCmd = &cobra.Command{
	Use:   "root",
	Short: "Print the project root directory name",
	Args:  cobra.NoArgs,
	RunE:  runRoot,
}

func runRoot(cmd *cobra.Command, args []string) error {
	root, err := utils.FindProjectRoot()
	if err != nil {
		return err
	}
	fmt.Println(filepath.Base(root))
	return nil
}
