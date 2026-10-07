package worktree

import (
	"testing"

	"alx/utils"
)

func TestMainSessionName_UsesWorktreeDirOfDefaultBranch(t *testing.T) {
	project := &utils.Project{Config: utils.ProjectConfig{Alias: "web"}}
	worktrees := []utils.WorktreeInfo{
		{Path: "dev", Branch: "dev"},
		{Path: "release_candidate", Branch: "release_candidate"},
	}

	got := mainSessionName(project, worktrees, "release_candidate")
	if got != "web-release_candidate" {
		t.Errorf("got %q, want web-release_candidate", got)
	}
}

func TestMainSessionName_DirNameDiffersFromBranch(t *testing.T) {
	project := &utils.Project{Config: utils.ProjectConfig{Alias: "web"}}
	worktrees := []utils.WorktreeInfo{
		{Path: "rc", Branch: "release_candidate"},
	}

	got := mainSessionName(project, worktrees, "release_candidate")
	if got != "web-rc" {
		t.Errorf("got %q, want web-rc", got)
	}
}

func TestMainSessionName_NoMatchingWorktree_FallsBackToBranch(t *testing.T) {
	project := &utils.Project{Config: utils.ProjectConfig{Alias: "dotf"}}
	worktrees := []utils.WorktreeInfo{
		{Path: "feat-auth", Branch: "feat/auth"},
	}

	got := mainSessionName(project, worktrees, "main")
	if got != "dotf-main" {
		t.Errorf("got %q, want dotf-main", got)
	}
}

func TestMainSessionName_NestedWorktreePath(t *testing.T) {
	project := &utils.Project{Config: utils.ProjectConfig{Alias: "web"}}
	worktrees := []utils.WorktreeInfo{
		{Path: "stacks/release_candidate", Branch: "release_candidate"},
	}

	got := mainSessionName(project, worktrees, "release_candidate")
	if got != "web-stacks/release_candidate" {
		t.Errorf("got %q, want web-stacks/release_candidate", got)
	}
}
