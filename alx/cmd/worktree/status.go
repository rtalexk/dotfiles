package worktree

import (
	"alx/utils"
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"text/tabwriter"

	"github.com/spf13/cobra"
)

var (
	statusFlagName   string
	statusFlagBranch string
	statusFlagJSON   bool
)

var StatusCmd = &cobra.Command{
	Use:   "status",
	Short: "Report the git and session state of a worktree",
	Args:  cobra.NoArgs,
	RunE:  runStatus,
}

func init() {
	StatusCmd.Flags().StringVar(&statusFlagName, "name", "", "Worktree directory name or path (default: the current worktree)")
	StatusCmd.Flags().StringVar(&statusFlagBranch, "branch", "", "Worktree branch (default: the current worktree)")
	StatusCmd.Flags().BoolVar(&statusFlagJSON, "json", false, "Emit a JSON object instead of a table")
}

type statusRecord struct {
	worktreeRecord
	Clean         bool     `json:"clean"`
	Staged        int      `json:"staged"`
	Modified      int      `json:"modified"`
	Untracked     int      `json:"untracked"`
	DirtyFiles    []string `json:"dirty_files"`
	Upstream      string   `json:"upstream"`
	Ahead         int      `json:"ahead"`
	Behind        int      `json:"behind"`
	AheadDefault  int      `json:"ahead_default"`
	BehindDefault int      `json:"behind_default"`
	Merged        bool     `json:"merged"`
	SessionExists bool     `json:"session_exists"`
}

type workingTreeState struct {
	Clean      bool
	Staged     int
	Modified   int
	Untracked  int
	DirtyFiles []string
}

func runStatus(cmd *cobra.Command, args []string) error {
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

	wt, err := resolveWorktree(worktrees, statusFlagName, statusFlagBranch)
	if err != nil {
		return err
	}

	defaultBranch := utils.DefaultBranch(bareDir, project.Config)
	record, err := collectStatus(wt, project, bareDir, defaultBranch)
	if err != nil {
		return err
	}

	if statusFlagJSON {
		return writeJSON(os.Stdout, record)
	}
	fmt.Print(renderStatus(record))
	return nil
}

func collectStatus(wt utils.WorktreeInfo, project *utils.Project, bareDir, defaultBranch string) (statusRecord, error) {
	record := statusRecord{
		worktreeRecord: newWorktreeRecord(wt, project, defaultBranch),
		DirtyFiles:     []string{},
	}

	out, err := exec.Command("git", "-C", wt.AbsPath, "status", "--porcelain").Output()
	if err != nil {
		return statusRecord{}, fmt.Errorf("failed to read worktree status: %w", err)
	}
	state := parsePorcelainStatus(string(out))
	record.Clean = state.Clean
	record.Staged = state.Staged
	record.Modified = state.Modified
	record.Untracked = state.Untracked
	if state.DirtyFiles != nil {
		record.DirtyFiles = state.DirtyFiles
	}

	if up, err := exec.Command("git", "-C", wt.AbsPath, "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}").Output(); err == nil {
		record.Upstream = strings.TrimSpace(string(up))
	}
	if record.Upstream != "" {
		behind, ahead, err := revListCounts(wt.AbsPath, record.Upstream, "HEAD")
		if err != nil {
			return statusRecord{}, err
		}
		record.Behind, record.Ahead = behind, ahead
	}

	if wt.Branch != defaultBranch && wt.Branch != "" {
		if behind, ahead, err := revListCounts(wt.AbsPath, defaultBranch, "HEAD"); err == nil {
			record.BehindDefault, record.AheadDefault = behind, ahead
		}
		merged, err := isMerged(bareDir, wt.Branch, defaultBranch)
		if err != nil {
			return statusRecord{}, err
		}
		record.Merged = merged
	} else {
		record.Merged = true
	}

	record.SessionExists = exec.Command("tmux", "has-session", "-t", "="+wt.Session).Run() == nil
	return record, nil
}

func revListCounts(dir, left, right string) (behind, ahead int, err error) {
	out, err := exec.Command("git", "-C", dir, "rev-list", "--left-right", "--count", left+"..."+right).Output()
	if err != nil {
		return 0, 0, fmt.Errorf("failed to compare %s with %s: %w", right, left, err)
	}
	return parseRevListCounts(string(out))
}

func parseRevListCounts(out string) (behind, ahead int, err error) {
	fields := strings.Fields(out)
	if len(fields) != 2 {
		return 0, 0, fmt.Errorf("unexpected rev-list output %q", strings.TrimSpace(out))
	}
	behind, err = strconv.Atoi(fields[0])
	if err != nil {
		return 0, 0, fmt.Errorf("unexpected rev-list output %q", strings.TrimSpace(out))
	}
	ahead, err = strconv.Atoi(fields[1])
	if err != nil {
		return 0, 0, fmt.Errorf("unexpected rev-list output %q", strings.TrimSpace(out))
	}
	return behind, ahead, nil
}

func parsePorcelainStatus(out string) workingTreeState {
	state := workingTreeState{Clean: true}
	for _, line := range strings.Split(out, "\n") {
		if len(line) < 4 {
			continue
		}
		state.Clean = false
		state.DirtyFiles = append(state.DirtyFiles, line)
		index, worktree := line[0], line[1]
		if index == '?' && worktree == '?' {
			state.Untracked++
			continue
		}
		if index != ' ' {
			state.Staged++
		}
		if worktree != ' ' {
			state.Modified++
		}
	}
	return state
}

func renderStatus(record statusRecord) string {
	var buf bytes.Buffer
	tw := tabwriter.NewWriter(&buf, 0, 0, 2, ' ', 0)

	fmt.Fprintf(tw, "name\t%s\n", record.Name)
	fmt.Fprintf(tw, "branch\t%s\n", record.Branch)
	fmt.Fprintf(tw, "path\t%s\n", record.AbsPath)
	fmt.Fprintf(tw, "session\t%s (%s)\n", record.Session, boolWord(record.SessionExists, "running", "stopped"))
	fmt.Fprintf(tw, "default branch\t%s%s\n", record.DefaultBranch, boolWord(record.IsDefaultBranch, " (this worktree)", ""))

	if record.Clean {
		fmt.Fprintf(tw, "working tree\tclean\n")
	} else {
		fmt.Fprintf(tw, "working tree\t%d staged, %d modified, %d untracked\n", record.Staged, record.Modified, record.Untracked)
	}

	if record.Upstream == "" {
		fmt.Fprintf(tw, "upstream\tnone\n")
	} else {
		fmt.Fprintf(tw, "upstream\t%s (ahead %d, behind %d)\n", record.Upstream, record.Ahead, record.Behind)
	}

	if !record.IsDefaultBranch {
		fmt.Fprintf(tw, "vs %s\tahead %d, behind %d\n", record.DefaultBranch, record.AheadDefault, record.BehindDefault)
		fmt.Fprintf(tw, "merged\t%s\n", boolWord(record.Merged, "yes", "no"))
	}

	tw.Flush()
	return buf.String()
}

func boolWord(cond bool, yes, no string) string {
	if cond {
		return yes
	}
	return no
}
