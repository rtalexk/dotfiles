package worktree

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func git(t *testing.T, dir string, args ...string) string {
	t.Helper()
	cmd := exec.Command("git", args...)
	cmd.Dir = dir
	cmd.Env = append(os.Environ(),
		"GIT_AUTHOR_NAME=T", "GIT_AUTHOR_EMAIL=t@t.com",
		"GIT_COMMITTER_NAME=T", "GIT_COMMITTER_EMAIL=t@t.com",
	)
	out, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("git %s in %s: %v\n%s", strings.Join(args, " "), dir, err, out)
	}
	return strings.TrimSpace(string(out))
}

// setupProject builds a bare-clone project with a default-branch worktree and
// returns the project root, the bare directory and the default branch name.
func setupProject(t *testing.T) (root, bareDir, defaultBranch string) {
	t.Helper()
	tmp, err := filepath.EvalSymlinks(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}

	source := filepath.Join(tmp, "source")
	if err := os.MkdirAll(source, 0755); err != nil {
		t.Fatal(err)
	}
	git(t, source, "init")
	if err := os.WriteFile(filepath.Join(source, "README.md"), []byte("hi\n"), 0644); err != nil {
		t.Fatal(err)
	}
	git(t, source, "add", "README.md")
	git(t, source, "commit", "-m", "init")
	defaultBranch = git(t, source, "branch", "--show-current")

	root = filepath.Join(tmp, "project")
	if err := os.MkdirAll(root, 0755); err != nil {
		t.Fatal(err)
	}
	bareDir = filepath.Join(root, ".bare")
	git(t, root, "clone", "--bare", source, bareDir)
	git(t, bareDir, "config", "remote.origin.fetch", "+refs/heads/*:refs/remotes/origin/*")
	git(t, bareDir, "fetch", "origin")
	git(t, bareDir, "worktree", "add", filepath.Join(root, defaultBranch), defaultBranch)
	return root, bareDir, defaultBranch
}
