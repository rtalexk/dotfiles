package worktree

import (
	"encoding/json"
	"slices"
	"strings"
	"testing"
)

func TestParsePorcelainStatusClean(t *testing.T) {
	state := parsePorcelainStatus("")
	if !state.Clean {
		t.Error("empty output means a clean worktree")
	}
	if state.Staged+state.Modified+state.Untracked != 0 {
		t.Errorf("counts should be zero, got %+v", state)
	}
}

func TestParsePorcelainStatusCounts(t *testing.T) {
	out := "A  added.go\n M modified.go\n?? new.txt\nMM both.go\n"
	state := parsePorcelainStatus(out)

	if state.Clean {
		t.Error("dirty output must not read as clean")
	}
	if state.Staged != 2 {
		t.Errorf("staged: got %d, want 2", state.Staged)
	}
	if state.Modified != 2 {
		t.Errorf("modified: got %d, want 2", state.Modified)
	}
	if state.Untracked != 1 {
		t.Errorf("untracked: got %d, want 1", state.Untracked)
	}
	if len(state.DirtyFiles) != 4 {
		t.Errorf("dirty files: got %d, want 4", len(state.DirtyFiles))
	}
}

func TestParsePorcelainStatusKeepsRenameLinesWhole(t *testing.T) {
	state := parsePorcelainStatus("R  old.go -> new.go\n")

	want := []string{"R  old.go -> new.go"}
	if !slices.Equal(state.DirtyFiles, want) {
		t.Errorf("got %q, want %q", state.DirtyFiles, want)
	}
	if state.Staged != 1 || state.Modified != 0 {
		t.Errorf("a staged rename: got staged=%d modified=%d", state.Staged, state.Modified)
	}
}

func TestParseRevListCounts(t *testing.T) {
	behind, ahead, err := parseRevListCounts("3\t5\n")
	if err != nil {
		t.Fatal(err)
	}
	if behind != 3 || ahead != 5 {
		t.Errorf("got behind=%d ahead=%d, want 3 and 5", behind, ahead)
	}
}

func TestParseRevListCountsRejectsGarbage(t *testing.T) {
	for _, out := range []string{"", "3", "a\tb", "1\t2\t3"} {
		if _, _, err := parseRevListCounts(out); err == nil {
			t.Errorf("%q: expected an error", out)
		}
	}
}

func TestRenderStatusCleanWorktree(t *testing.T) {
	record := statusRecord{
		worktreeRecord: worktreeRecord{
			Name: "feat-auth", Branch: "feat/auth", AbsPath: "/p/feat-auth",
			Session: "dotf-feat-auth", DefaultBranch: "main",
		},
		Clean:         true,
		DirtyFiles:    []string{},
		Upstream:      "origin/feat/auth",
		Ahead:         2,
		AheadDefault:  3,
		BehindDefault: 1,
		SessionExists: true,
	}

	out := renderStatus(record)
	for _, want := range []string{
		"working tree", "clean",
		"origin/feat/auth (ahead 2, behind 0)",
		"vs main", "ahead 3, behind 1",
		"merged", "no",
		"dotf-feat-auth (running)",
	} {
		if !strings.Contains(out, want) {
			t.Errorf("output is missing %q:\n%s", want, out)
		}
	}
}

func TestRenderStatusOnDefaultBranchOmitsComparison(t *testing.T) {
	record := statusRecord{
		worktreeRecord: worktreeRecord{
			Name: "main", Branch: "main", DefaultBranch: "main", IsDefaultBranch: true,
		},
		Clean:      true,
		DirtyFiles: []string{},
		Merged:     true,
	}

	out := renderStatus(record)
	if strings.Contains(out, "vs main") {
		t.Errorf("the default branch worktree needs no comparison:\n%s", out)
	}
	if !strings.Contains(out, "upstream") || !strings.Contains(out, "none") {
		t.Errorf("a branch without an upstream should say so:\n%s", out)
	}
}

func TestStatusRecordJSONIsFlat(t *testing.T) {
	record := statusRecord{
		worktreeRecord: worktreeRecord{Name: "feat-auth", Branch: "feat/auth"},
		DirtyFiles:     []string{},
	}

	data, err := json.Marshal(record)
	if err != nil {
		t.Fatal(err)
	}

	var decoded map[string]any
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatal(err)
	}
	for _, key := range []string{"name", "branch", "clean", "dirty_files", "merged", "session_exists", "ahead", "behind"} {
		if _, ok := decoded[key]; !ok {
			t.Errorf("missing key %q in %s", key, data)
		}
	}
	if _, ok := decoded["worktreeRecord"]; ok {
		t.Errorf("the embedded record must flatten: %s", data)
	}
}

func TestStatusRecordJSONEmitsEmptyDirtyFileArray(t *testing.T) {
	data, err := json.Marshal(statusRecord{DirtyFiles: []string{}})
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(data), `"dirty_files":[]`) {
		t.Errorf("dirty_files should be an empty array, got %s", data)
	}
}
