package utils_test

import (
	"path/filepath"
	"testing"

	"alx/utils"
)

func setupBareProject(t *testing.T) (realTmp, bare string) {
	t.Helper()
	tmp := t.TempDir()

	source := filepath.Join(tmp, "source")
	if err := runCmd(tmp, "git", "init", source); err != nil {
		t.Fatal(err)
	}
	if err := runCmd(source, "git", "-c", "user.email=t@t.com", "-c", "user.name=T",
		"commit", "--allow-empty", "-m", "init"); err != nil {
		t.Fatal(err)
	}

	bare = filepath.Join(tmp, ".bare")
	if err := runCmd(tmp, "git", "clone", "--bare", source, bare); err != nil {
		t.Fatal(err)
	}

	realTmp, err := filepath.EvalSymlinks(tmp)
	if err != nil {
		t.Fatal(err)
	}
	bare = filepath.Join(realTmp, ".bare")
	return realTmp, bare
}

func TestListWorktrees_ExcludesBare(t *testing.T) {
	root, bare := setupBareProject(t)
	mainWT := filepath.Join(root, "main")
	if err := runCmd(bare, "git", "worktree", "add", mainWT); err != nil {
		t.Fatal(err)
	}

	project := &utils.Project{Root: root, Config: utils.ProjectConfig{Alias: "myapp"}}
	worktrees, err := utils.ListWorktrees(bare, root, project)
	if err != nil {
		t.Fatal(err)
	}

	for _, wt := range worktrees {
		if wt.Path == ".bare" || wt.Path == "bare" {
			t.Errorf("bare should not appear in list, got path %q", wt.Path)
		}
	}
}

func TestListWorktrees_IncludesMain(t *testing.T) {
	root, bare := setupBareProject(t)
	mainWT := filepath.Join(root, "main")
	if err := runCmd(bare, "git", "worktree", "add", mainWT); err != nil {
		t.Fatal(err)
	}

	project := &utils.Project{Root: root, Config: utils.ProjectConfig{Alias: "myapp"}}
	worktrees, err := utils.ListWorktrees(bare, root, project)
	if err != nil {
		t.Fatal(err)
	}

	found := false
	for _, wt := range worktrees {
		if wt.Path == "main" {
			found = true
		}
	}
	if !found {
		t.Error("expected 'main' worktree in list")
	}
}

func TestListWorktrees_RelativePath(t *testing.T) {
	root, bare := setupBareProject(t)
	mainWT := filepath.Join(root, "main")
	if err := runCmd(bare, "git", "worktree", "add", mainWT); err != nil {
		t.Fatal(err)
	}
	featureWT := filepath.Join(root, "feature-x")
	if err := runCmd(bare, "git", "worktree", "add", "-b", "feature-x", featureWT); err != nil {
		t.Fatal(err)
	}

	project := &utils.Project{Root: root, Config: utils.ProjectConfig{Alias: "myapp"}}
	worktrees, err := utils.ListWorktrees(bare, root, project)
	if err != nil {
		t.Fatal(err)
	}

	if len(worktrees) != 2 {
		t.Fatalf("expected 2 worktrees, got %d", len(worktrees))
	}
	paths := map[string]bool{}
	for _, wt := range worktrees {
		paths[wt.Path] = true
	}
	if !paths["main"] {
		t.Error("expected path 'main'")
	}
	if !paths["feature-x"] {
		t.Error("expected path 'feature-x'")
	}
}

func TestListWorktrees_BranchName(t *testing.T) {
	root, bare := setupBareProject(t)
	featureWT := filepath.Join(root, "feature-x")
	if err := runCmd(bare, "git", "worktree", "add", "-b", "feature-x", featureWT); err != nil {
		t.Fatal(err)
	}

	project := &utils.Project{Root: root, Config: utils.ProjectConfig{Alias: "myapp"}}
	worktrees, err := utils.ListWorktrees(bare, root, project)
	if err != nil {
		t.Fatal(err)
	}

	for _, wt := range worktrees {
		if wt.Path == "feature-x" && wt.Branch != "feature-x" {
			t.Errorf("expected branch 'feature-x', got %q", wt.Branch)
		}
	}
}

func TestListWorktrees_SessionName(t *testing.T) {
	root, bare := setupBareProject(t)
	featureWT := filepath.Join(root, "feat")
	if err := runCmd(bare, "git", "worktree", "add", "-b", "feat", featureWT); err != nil {
		t.Fatal(err)
	}

	project := &utils.Project{Root: root, Config: utils.ProjectConfig{Alias: "myapp"}}
	worktrees, err := utils.ListWorktrees(bare, root, project)
	if err != nil {
		t.Fatal(err)
	}

	for _, wt := range worktrees {
		if wt.Path == "feat" && wt.Session != "myapp-feat" {
			t.Errorf("expected session 'myapp-feat', got %q", wt.Session)
		}
	}
}

func TestListWorktrees_RootRelativeToProjects(t *testing.T) {
	root, bare := setupBareProject(t)
	mainWT := filepath.Join(root, "main")
	if err := runCmd(bare, "git", "worktree", "add", mainWT); err != nil {
		t.Fatal(err)
	}

	// root is e.g. /tmp/TestXxx/001
	// Set PROJECTS to its parent so root relative = last segment
	parent := filepath.Dir(root)
	t.Setenv("PROJECTS", parent)

	project := &utils.Project{Root: root, Config: utils.ProjectConfig{Alias: "myapp"}}
	worktrees, err := utils.ListWorktrees(bare, root, project)
	if err != nil {
		t.Fatal(err)
	}

	expected := filepath.Base(root)
	for _, wt := range worktrees {
		if wt.Root != expected {
			t.Errorf("expected Root %q, got %q", expected, wt.Root)
		}
	}
}

func TestListWorktrees_RootAbsoluteWhenProjectsUnset(t *testing.T) {
	root, bare := setupBareProject(t)
	mainWT := filepath.Join(root, "main")
	if err := runCmd(bare, "git", "worktree", "add", mainWT); err != nil {
		t.Fatal(err)
	}

	t.Setenv("PROJECTS", "")

	project := &utils.Project{Root: root, Config: utils.ProjectConfig{Alias: "myapp"}}
	worktrees, err := utils.ListWorktrees(bare, root, project)
	if err != nil {
		t.Fatal(err)
	}

	for _, wt := range worktrees {
		if wt.Root != root {
			t.Errorf("expected Root %q, got %q", root, wt.Root)
		}
	}
}
