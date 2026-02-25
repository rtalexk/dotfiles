package worktree

import (
	"alx/utils"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"text/tabwriter"
	"text/template"

	"github.com/spf13/cobra"
)

var (
	listFlagRoot    bool
	listFlagBranch  bool
	listFlagSession bool
	listFlagFormat  string
)

var ListCmd = &cobra.Command{
	Use:   "list",
	Short: "List worktrees, one per line",
	Args:  cobra.NoArgs,
	RunE:  runList,
}

func init() {
	ListCmd.Flags().BoolVarP(&listFlagRoot, "root", "r", false, "Include project root column (relative to $PROJECTS)")
	ListCmd.Flags().BoolVarP(&listFlagBranch, "branch", "b", false, "Include branch column")
	ListCmd.Flags().BoolVarP(&listFlagSession, "session", "s", false, "Include session name column")
	ListCmd.Flags().StringVar(&listFlagFormat, "format", "", `Go template (fields: Path, Root, Branch, Session); e.g. "{{.Path}}\t{{.Branch}}"`)
}

func runList(cmd *cobra.Command, args []string) error {
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

	if listFlagFormat != "" {
		expanded := strings.NewReplacer(`\t`, "\t", `\n`, "\n").Replace(listFlagFormat)
		tmpl, err := template.New("row").Parse(expanded + "\n")
		if err != nil {
			return fmt.Errorf("invalid format template: %w", err)
		}
		for _, wt := range worktrees {
			if err := tmpl.Execute(os.Stdout, wt); err != nil {
				return err
			}
		}
		return nil
	}

	multiCol := listFlagRoot || listFlagBranch || listFlagSession
	if multiCol {
		tw := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
		for _, wt := range worktrees {
			parts := []string{wt.Path}
			if listFlagRoot {
				parts = append(parts, wt.Root)
			}
			if listFlagBranch {
				parts = append(parts, wt.Branch)
			}
			if listFlagSession {
				parts = append(parts, wt.Session)
			}
			fmt.Fprintln(tw, strings.Join(parts, "\t"))
		}
		return tw.Flush()
	}

	for _, wt := range worktrees {
		fmt.Println(wt.Path)
	}
	return nil
}
