package worktree

import (
	"strings"
	"testing"

	"alx/utils"
)

func sampleWorktrees() []utils.WorktreeInfo {
	return []utils.WorktreeInfo{
		{Path: "main", AbsPath: "/p/main", Branch: "main"},
		{Path: "feat-auth", AbsPath: "/p/feat-auth", Branch: "feat/auth"},
		{Path: "stacks/rc", AbsPath: "/p/stacks/rc", Branch: "release_candidate"},
	}
}

func TestSelectWorktreeByBranch(t *testing.T) {
	wt, err := selectWorktree(sampleWorktrees(), "", "feat/auth")
	if err != nil {
		t.Fatal(err)
	}
	if wt.Path != "feat-auth" {
		t.Errorf("got %q, want feat-auth", wt.Path)
	}
}

func TestSelectWorktreeByRelativePath(t *testing.T) {
	wt, err := selectWorktree(sampleWorktrees(), "stacks/rc", "")
	if err != nil {
		t.Fatal(err)
	}
	if wt.Branch != "release_candidate" {
		t.Errorf("got %q, want release_candidate", wt.Branch)
	}
}

func TestSelectWorktreeByDirectoryName(t *testing.T) {
	wt, err := selectWorktree(sampleWorktrees(), "rc", "")
	if err != nil {
		t.Fatal(err)
	}
	if wt.Path != "stacks/rc" {
		t.Errorf("got %q, want stacks/rc", wt.Path)
	}
}

func TestSelectWorktreePrefersExactPathOverDirectoryName(t *testing.T) {
	worktrees := []utils.WorktreeInfo{
		{Path: "rc", Branch: "rc"},
		{Path: "stacks/rc", Branch: "release_candidate"},
	}

	wt, err := selectWorktree(worktrees, "rc", "")
	if err != nil {
		t.Fatal(err)
	}
	if wt.Path != "rc" {
		t.Errorf("got %q, want rc", wt.Path)
	}
}

func TestSelectWorktreeAmbiguousDirectoryName(t *testing.T) {
	worktrees := []utils.WorktreeInfo{
		{Path: "a/rc", Branch: "one"},
		{Path: "b/rc", Branch: "two"},
	}

	_, err := selectWorktree(worktrees, "rc", "")
	if err == nil {
		t.Fatal("expected an ambiguity error, got nil")
	}
	if !strings.Contains(err.Error(), "a/rc") || !strings.Contains(err.Error(), "b/rc") {
		t.Errorf("error should name both candidates: %v", err)
	}
}

func TestSelectWorktreeRejectsBothSelectors(t *testing.T) {
	if _, err := selectWorktree(sampleWorktrees(), "main", "main"); err == nil {
		t.Fatal("expected an error when both --name and --branch are given")
	}
}

func TestSelectWorktreeUnknown(t *testing.T) {
	if _, err := selectWorktree(sampleWorktrees(), "nope", ""); err == nil {
		t.Fatal("expected an error for an unknown name")
	}
	if _, err := selectWorktree(sampleWorktrees(), "", "nope"); err == nil {
		t.Fatal("expected an error for an unknown branch")
	}
}

func TestSelectWorktreeWithNoSelector(t *testing.T) {
	if _, err := selectWorktree(sampleWorktrees(), "", ""); err == nil {
		t.Fatal("expected an error when nothing is selected")
	}
}

func TestCurrentWorktreeAtWorktreeRoot(t *testing.T) {
	wt, err := currentWorktree(sampleWorktrees(), "/p/feat-auth")
	if err != nil {
		t.Fatal(err)
	}
	if wt.Path != "feat-auth" {
		t.Errorf("got %q, want feat-auth", wt.Path)
	}
}

func TestCurrentWorktreeFromNestedDirectory(t *testing.T) {
	wt, err := currentWorktree(sampleWorktrees(), "/p/feat-auth/cmd/worktree")
	if err != nil {
		t.Fatal(err)
	}
	if wt.Path != "feat-auth" {
		t.Errorf("got %q, want feat-auth", wt.Path)
	}
}

func TestCurrentWorktreePrefersDeepestMatch(t *testing.T) {
	worktrees := []utils.WorktreeInfo{
		{Path: "outer", AbsPath: "/p/outer", Branch: "outer"},
		{Path: "outer/inner", AbsPath: "/p/outer/inner", Branch: "inner"},
	}

	wt, err := currentWorktree(worktrees, "/p/outer/inner/sub")
	if err != nil {
		t.Fatal(err)
	}
	if wt.Path != "outer/inner" {
		t.Errorf("got %q, want outer/inner", wt.Path)
	}
}

func TestCurrentWorktreeOutsideAnyWorktree(t *testing.T) {
	if _, err := currentWorktree(sampleWorktrees(), "/elsewhere"); err == nil {
		t.Fatal("expected an error outside every worktree")
	}
}

func TestCurrentWorktreeIgnoresSharedPathPrefix(t *testing.T) {
	worktrees := []utils.WorktreeInfo{
		{Path: "feat", AbsPath: "/p/feat", Branch: "feat"},
	}

	if _, err := currentWorktree(worktrees, "/p/feature"); err == nil {
		t.Fatal("/p/feature is not inside /p/feat")
	}
}

func TestCurrentWorktreeSkipsEntriesWithoutAbsolutePath(t *testing.T) {
	worktrees := []utils.WorktreeInfo{{Path: "main", Branch: "main"}}

	if _, err := currentWorktree(worktrees, "/p/main"); err == nil {
		t.Fatal("expected an error when no entry carries an absolute path")
	}
}
