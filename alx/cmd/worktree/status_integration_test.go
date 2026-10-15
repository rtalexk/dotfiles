package worktree

import (
	"os"
	"path/filepath"
	"testing"

	"alx/utils"
)

func statusOf(t *testing.T, root, bareDir, defaultBranch, name string) statusRecord {
	t.Helper()
	project := &utils.Project{Root: root, Config: utils.ProjectConfig{Alias: "proj"}}
	worktrees, err := utils.ListWorktrees(bareDir, root, project)
	if err != nil {
		t.Fatal(err)
	}
	wt, err := selectWorktree(worktrees, name, "")
	if err != nil {
		t.Fatal(err)
	}
	record, err := collectStatus(wt, project, bareDir, defaultBranch)
	if err != nil {
		t.Fatal(err)
	}
	return record
}

func TestCollectStatusOnACleanDefaultBranchWorktree(t *testing.T) {
	root, bareDir, defaultBranch := setupProject(t)

	record := statusOf(t, root, bareDir, defaultBranch, defaultBranch)

	if !record.Clean {
		t.Errorf("a fresh worktree is clean, got %+v", record.DirtyFiles)
	}
	if !record.IsDefaultBranch {
		t.Error("this worktree holds the default branch")
	}
	if !record.Merged {
		t.Error("the default branch counts as merged")
	}
	if record.AbsPath != filepath.Join(root, defaultBranch) {
		t.Errorf("abs_path: got %q", record.AbsPath)
	}
}

func TestCollectStatusCountsAheadOfDefaultBranch(t *testing.T) {
	root, bareDir, defaultBranch := setupProject(t)
	featDir := filepath.Join(root, "feat")
	git(t, bareDir, "worktree", "add", "-b", "feat", featDir)
	if err := os.WriteFile(filepath.Join(featDir, "new.txt"), []byte("x\n"), 0644); err != nil {
		t.Fatal(err)
	}
	git(t, featDir, "add", "new.txt")
	git(t, featDir, "commit", "-m", "add new")

	record := statusOf(t, root, bareDir, defaultBranch, "feat")

	if record.AheadDefault != 1 {
		t.Errorf("ahead_default: got %d, want 1", record.AheadDefault)
	}
	if record.BehindDefault != 0 {
		t.Errorf("behind_default: got %d, want 0", record.BehindDefault)
	}
	if record.Merged {
		t.Error("a branch with its own commit is not merged")
	}
	if record.Upstream != "" {
		t.Errorf("upstream: got %q, want empty", record.Upstream)
	}
}

func TestCollectStatusReportsADirtyWorktree(t *testing.T) {
	root, bareDir, defaultBranch := setupProject(t)
	featDir := filepath.Join(root, "feat")
	git(t, bareDir, "worktree", "add", "-b", "feat", featDir)

	if err := os.WriteFile(filepath.Join(featDir, "README.md"), []byte("changed\n"), 0644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(featDir, "untracked.txt"), []byte("x\n"), 0644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(featDir, "staged.txt"), []byte("x\n"), 0644); err != nil {
		t.Fatal(err)
	}
	git(t, featDir, "add", "staged.txt")

	record := statusOf(t, root, bareDir, defaultBranch, "feat")

	if record.Clean {
		t.Fatal("the worktree has changes")
	}
	if record.Staged != 1 {
		t.Errorf("staged: got %d, want 1", record.Staged)
	}
	if record.Modified != 1 {
		t.Errorf("modified: got %d, want 1", record.Modified)
	}
	if record.Untracked != 1 {
		t.Errorf("untracked: got %d, want 1", record.Untracked)
	}
	if len(record.DirtyFiles) != 3 {
		t.Errorf("dirty_files: got %v", record.DirtyFiles)
	}
}

func TestCollectStatusReadsTheUpstreamBranch(t *testing.T) {
	root, bareDir, defaultBranch := setupProject(t)
	featDir := filepath.Join(root, "feat")
	git(t, bareDir, "worktree", "add", "-b", "feat", featDir)
	git(t, bareDir, "update-ref", "refs/remotes/origin/feat", "refs/heads/feat")
	git(t, featDir, "branch", "--set-upstream-to=origin/feat", "feat")
	if err := os.WriteFile(filepath.Join(featDir, "new.txt"), []byte("x\n"), 0644); err != nil {
		t.Fatal(err)
	}
	git(t, featDir, "add", "new.txt")
	git(t, featDir, "commit", "-m", "add new")

	record := statusOf(t, root, bareDir, defaultBranch, "feat")

	if record.Upstream != "origin/feat" {
		t.Fatalf("upstream: got %q, want origin/feat", record.Upstream)
	}
	if record.Ahead != 1 {
		t.Errorf("ahead: got %d, want 1", record.Ahead)
	}
	if record.Behind != 0 {
		t.Errorf("behind: got %d, want 0", record.Behind)
	}
}

func TestCollectStatusSeesAMergedBranch(t *testing.T) {
	root, bareDir, defaultBranch := setupProject(t)
	featDir := filepath.Join(root, "feat")
	git(t, bareDir, "worktree", "add", "-b", "feat", featDir)

	record := statusOf(t, root, bareDir, defaultBranch, "feat")

	if !record.Merged {
		t.Error("a branch with no commits of its own is merged")
	}
	if record.AheadDefault != 0 {
		t.Errorf("ahead_default: got %d, want 0", record.AheadDefault)
	}
}
