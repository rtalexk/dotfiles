package worktree

import (
	"os"
	"path/filepath"
	"testing"
)

func TestIsMergedSeesABranchCheckedOutInAnotherWorktree(t *testing.T) {
	root, bareDir, defaultBranch := setupProject(t)
	git(t, bareDir, "worktree", "add", "-b", "feat", filepath.Join(root, "feat"))

	merged, err := isMerged(bareDir, "feat", defaultBranch)
	if err != nil {
		t.Fatal(err)
	}
	if !merged {
		t.Error("a branch at the tip of the default branch is merged, even though the listing marks it with '+'")
	}
}

func TestIsMergedRejectsABranchWithItsOwnCommit(t *testing.T) {
	root, bareDir, defaultBranch := setupProject(t)
	featDir := filepath.Join(root, "feat")
	git(t, bareDir, "worktree", "add", "-b", "feat", featDir)
	if err := os.WriteFile(filepath.Join(featDir, "new.txt"), []byte("x\n"), 0644); err != nil {
		t.Fatal(err)
	}
	git(t, featDir, "add", "new.txt")
	git(t, featDir, "commit", "-m", "add new")

	merged, err := isMerged(bareDir, "feat", defaultBranch)
	if err != nil {
		t.Fatal(err)
	}
	if merged {
		t.Error("a branch ahead of the default branch is not merged")
	}
}

func TestIsMergedDoesNotMatchAPrefixOfAnotherBranch(t *testing.T) {
	root, bareDir, defaultBranch := setupProject(t)
	git(t, bareDir, "worktree", "add", "-b", "feature", filepath.Join(root, "feature"))

	merged, err := isMerged(bareDir, "feat", defaultBranch)
	if err != nil {
		t.Fatal(err)
	}
	if merged {
		t.Error("'feat' does not exist; only 'feature' does")
	}
}
