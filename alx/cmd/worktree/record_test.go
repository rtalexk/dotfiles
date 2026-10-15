package worktree

import (
	"bytes"
	"encoding/json"
	"strings"
	"testing"
	"time"

	"alx/utils"
)

func TestNewWorktreeRecordMapsFields(t *testing.T) {
	created := time.Date(2026, 10, 1, 12, 0, 0, 0, time.UTC)
	commit := time.Date(2026, 10, 14, 9, 30, 0, 0, time.UTC)
	wt := utils.WorktreeInfo{
		Path: "stacks/rc", AbsPath: "/p/stacks/rc", Root: "com.github/dotfiles",
		Branch: "release_candidate", Session: "dotf-stacks/rc",
		CreatedAt: created, LastCommitAt: commit, LastCommitMsg: "fix: thing",
	}
	project := &utils.Project{Config: utils.ProjectConfig{Alias: "dotf"}}

	record := newWorktreeRecord(wt, project, "release_candidate")

	if record.Name != "rc" {
		t.Errorf("name: got %q, want rc", record.Name)
	}
	if record.Alias != "dotf" {
		t.Errorf("alias: got %q, want dotf", record.Alias)
	}
	if !record.IsDefaultBranch {
		t.Error("release_candidate is the default branch here")
	}
	if record.CreatedAt != "2026-10-01T12:00:00Z" {
		t.Errorf("created_at: got %q", record.CreatedAt)
	}
	if record.LastCommitAt != "2026-10-14T09:30:00Z" {
		t.Errorf("last_commit_at: got %q", record.LastCommitAt)
	}
}

func TestNewWorktreeRecordOmitsZeroTimes(t *testing.T) {
	project := &utils.Project{Config: utils.ProjectConfig{Alias: "dotf"}}
	record := newWorktreeRecord(utils.WorktreeInfo{Path: "main", Branch: "main"}, project, "main")

	data, err := json.Marshal(record)
	if err != nil {
		t.Fatal(err)
	}
	for _, key := range []string{"created_at", "last_commit_at", "last_commit_msg"} {
		if strings.Contains(string(data), key) {
			t.Errorf("%q should be omitted when empty: %s", key, data)
		}
	}
}

func TestWriteJSONIsIndentedAndNewlineTerminated(t *testing.T) {
	var buf bytes.Buffer
	if err := writeJSON(&buf, worktreeRecord{Name: "main", Branch: "main"}); err != nil {
		t.Fatal(err)
	}

	out := buf.String()
	if !strings.HasSuffix(out, "\n") {
		t.Error("output must end with a newline")
	}
	if !strings.Contains(out, "\n  \"name\": \"main\"") {
		t.Errorf("output should be indented:\n%s", out)
	}
}

func TestWriteJSONKeepsBranchCharactersUnescaped(t *testing.T) {
	var buf bytes.Buffer
	if err := writeJSON(&buf, worktreeRecord{Branch: "feat/a&b"}); err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(buf.String(), "feat/a&b") {
		t.Errorf("HTML escaping should be off:\n%s", buf.String())
	}
}
