package worktree

import (
	"alx/utils"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"text/tabwriter"
	"text/template"
	"time"

	"github.com/spf13/cobra"
)

var (
	listFlagNameOnly bool
	listFlagAlias    bool
	listFlagFormat   string
)

var ListCmd = &cobra.Command{
	Use:   "list",
	Short: "List worktrees",
	Args:  cobra.NoArgs,
	RunE:  runList,
}

func init() {
	ListCmd.Flags().BoolVar(&listFlagNameOnly, "name-only", false, "Print only worktree names, one per line")
	ListCmd.Flags().BoolVarP(&listFlagAlias, "alias", "a", false, "Prefix name with project alias (e.g. dotf-main)")
	ListCmd.Flags().StringVar(&listFlagFormat, "format", "", `Go template (fields: Path, Root, Branch, Session, CreatedAt, LastCommitAt, LastCommitMsg)`)
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

	if listFlagNameOnly {
		for _, wt := range worktrees {
			fmt.Println(wtName(wt, project, listFlagAlias))
		}
		return nil
	}

	const bold = "\033[1m"
	const reset = "\033[0m"

	e := string(tabwriter.Escape)
	tw := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', tabwriter.StripEscape)
	headers := []string{"Name", "Tmux", "Branch", "Path", "Age", "Upd", "Message"}
	for i, h := range headers {
		if i > 0 {
			fmt.Fprint(tw, "\t")
		}
		fmt.Fprintf(tw, "%s%s%s%s%s", e, bold, e, h, e+reset+e)
	}
	fmt.Fprintln(tw)
	for _, wt := range worktrees {
		fmt.Fprintf(tw, "%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
			wtName(wt, project, listFlagAlias),
			wt.Session,
			wt.Branch,
			wt.Path,
			formatAge(wt.CreatedAt),
			formatAge(wt.LastCommitAt),
			truncate(wt.LastCommitMsg, 40),
		)
	}
	return tw.Flush()
}

func wtName(wt utils.WorktreeInfo, project *utils.Project, withAlias bool) string {
	name := filepath.Base(wt.Path)
	if withAlias {
		return project.Config.Alias + "-" + name
	}
	return name
}

func truncate(s string, max int) string {
	runes := []rune(s)
	if len(runes) <= max {
		return s
	}
	return string(runes[:max]) + "…"
}

func formatAge(t time.Time) string {
	if t.IsZero() {
		return "-"
	}
	d := time.Since(t)
	switch {
	case d < time.Minute:
		return "now"
	case d < time.Hour:
		return fmt.Sprintf("%dm", int(d.Minutes()))
	case d < 24*time.Hour:
		return fmt.Sprintf("%dh", int(d.Hours()))
	case d < 30*24*time.Hour:
		return fmt.Sprintf("%dd", int(d.Hours()/24))
	case d < 365*24*time.Hour:
		return fmt.Sprintf("%dmo", int(d.Hours()/24/30))
	default:
		return fmt.Sprintf("%dy", int(d.Hours()/24/365))
	}
}
