package worktree

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"

	"alx/utils"
)

func TestProjectInitEnablesNativeGitDiscoveryFromNestedDirectory(t *testing.T) {
	root := t.TempDir()
	if err := exec.Command("git", "init", "--bare", filepath.Join(root, ".bare")).Run(); err != nil {
		t.Fatalf("git init --bare: %v", err)
	}

	originalDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = os.Chdir(originalDir) })
	if err := os.Chdir(root); err != nil {
		t.Fatal(err)
	}
	projectForceFlag = false

	if err := runProjectInit(nil, nil); err != nil {
		t.Fatalf("runProjectInit: %v", err)
	}
	gitFileContents, err := os.ReadFile(filepath.Join(root, ".git"))
	if err != nil {
		t.Fatal(err)
	}
	if string(gitFileContents) != "gitdir: ./.bare\n" {
		t.Fatalf(".git contains %q", gitFileContents)
	}

	nested := filepath.Join(root, "nested")
	if err := os.Mkdir(nested, 0755); err != nil {
		t.Fatal(err)
	}
	cmd := exec.Command("git", "rev-parse", "--git-common-dir", "--is-bare-repository")
	cmd.Dir = nested
	out, err := cmd.Output()
	if err != nil {
		t.Fatalf("native git discovery: %v", err)
	}
	lines := strings.Split(strings.TrimSpace(string(out)), "\n")
	if len(lines) != 2 {
		t.Fatalf("unexpected git output: %q", out)
	}
	resolvedBare, err := filepath.EvalSymlinks(lines[0])
	if err != nil {
		t.Fatal(err)
	}
	wantBare, err := filepath.EvalSymlinks(filepath.Join(root, ".bare"))
	if err != nil {
		t.Fatal(err)
	}
	if resolvedBare != wantBare || lines[1] != "true" {
		t.Fatalf("git resolved (%q, %q), want (%q, true)", resolvedBare, lines[1], wantBare)
	}

	if err := os.Chdir(nested); err != nil {
		t.Fatal(err)
	}
	projectRoot, err := utils.FindProjectRoot()
	if err != nil {
		t.Fatalf("FindProjectRoot from nested directory: %v", err)
	}
	wantRoot, err := filepath.EvalSymlinks(root)
	if err != nil {
		t.Fatal(err)
	}
	if projectRoot != wantRoot {
		t.Fatalf("FindProjectRoot returned %q, want %q", projectRoot, wantRoot)
	}
}

func TestProjectInitDoesNotOverwriteExistingGitFile(t *testing.T) {
	root := t.TempDir()
	if err := exec.Command("git", "init", "--bare", filepath.Join(root, ".bare")).Run(); err != nil {
		t.Fatalf("git init --bare: %v", err)
	}
	gitFilePath := filepath.Join(root, ".git")
	if err := os.WriteFile(gitFilePath, []byte("existing git metadata\n"), 0644); err != nil {
		t.Fatal(err)
	}

	originalDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = os.Chdir(originalDir) })
	if err := os.Chdir(root); err != nil {
		t.Fatal(err)
	}
	projectForceFlag = false

	if err := runProjectInit(nil, nil); err != nil {
		t.Fatalf("runProjectInit: %v", err)
	}

	contents, err := os.ReadFile(gitFilePath)
	if err != nil {
		t.Fatal(err)
	}
	if string(contents) != "existing git metadata\n" {
		t.Fatalf("existing .git changed to %q", contents)
	}
}

func TestProjectInitDoesNotOverwriteExistingGitDirectory(t *testing.T) {
	root := t.TempDir()
	if err := exec.Command("git", "init", "--bare", filepath.Join(root, ".bare")).Run(); err != nil {
		t.Fatalf("git init --bare: %v", err)
	}
	gitDirectory := filepath.Join(root, ".git")
	if err := os.Mkdir(gitDirectory, 0755); err != nil {
		t.Fatal(err)
	}
	markerPath := filepath.Join(gitDirectory, "keep")
	if err := os.WriteFile(markerPath, []byte("existing git metadata\n"), 0644); err != nil {
		t.Fatal(err)
	}

	originalDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = os.Chdir(originalDir) })
	if err := os.Chdir(root); err != nil {
		t.Fatal(err)
	}
	projectForceFlag = false

	if err := runProjectInit(nil, nil); err != nil {
		t.Fatalf("runProjectInit: %v", err)
	}

	contents, err := os.ReadFile(markerPath)
	if err != nil {
		t.Fatal(err)
	}
	if string(contents) != "existing git metadata\n" {
		t.Fatalf("existing .git directory contents changed to %q", contents)
	}
}
