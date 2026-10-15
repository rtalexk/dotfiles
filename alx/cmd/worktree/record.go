package worktree

import (
	"alx/utils"
	"encoding/json"
	"io"
	"path/filepath"
	"time"
)

type worktreeRecord struct {
	Name            string `json:"name"`
	Path            string `json:"path"`
	AbsPath         string `json:"abs_path"`
	Branch          string `json:"branch"`
	Session         string `json:"session"`
	Alias           string `json:"alias"`
	Root            string `json:"root"`
	DefaultBranch   string `json:"default_branch"`
	IsDefaultBranch bool   `json:"is_default_branch"`
	CreatedAt       string `json:"created_at,omitempty"`
	LastCommitAt    string `json:"last_commit_at,omitempty"`
	LastCommitMsg   string `json:"last_commit_msg,omitempty"`
}

func newWorktreeRecord(wt utils.WorktreeInfo, project *utils.Project, defaultBranch string) worktreeRecord {
	return worktreeRecord{
		Name:            filepath.Base(wt.Path),
		Path:            wt.Path,
		AbsPath:         wt.AbsPath,
		Branch:          wt.Branch,
		Session:         wt.Session,
		Alias:           project.Config.Alias,
		Root:            wt.Root,
		DefaultBranch:   defaultBranch,
		IsDefaultBranch: wt.Branch == defaultBranch,
		CreatedAt:       formatTimestamp(wt.CreatedAt),
		LastCommitAt:    formatTimestamp(wt.LastCommitAt),
		LastCommitMsg:   wt.LastCommitMsg,
	}
}

func formatTimestamp(t time.Time) string {
	if t.IsZero() {
		return ""
	}
	return t.Format(time.RFC3339)
}

func writeJSON(w io.Writer, v any) error {
	enc := json.NewEncoder(w)
	enc.SetIndent("", "  ")
	enc.SetEscapeHTML(false)
	return enc.Encode(v)
}
