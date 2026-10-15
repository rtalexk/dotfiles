package worktree

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func refExists(dir, ref string) bool {
	return exec.Command("git", "-C", dir, "rev-parse", "--verify", "--quiet", ref).Run() == nil
}

// Payloads copied verbatim from `gh issue view` and `gh pr view` against
// cli/cli, so the structs keep matching what gh actually prints.
const (
	liveIssueJSON       = `{"number":1,"title":"interactive pr list"}`
	liveSameRepoPRJSON  = `{"headRefName":"dependabot/github_actions/goreleaser/goreleaser-action-7.3.0","isCrossRepository":false,"number":14707,"state":"MERGED"}`
	liveCrossRepoPRJSON = `{"headRefName":"14692-fix-issue-view-comments-body","isCrossRepository":true,"number":14710,"state":"OPEN"}`
)

func TestDecodeIssueFromLivePayload(t *testing.T) {
	info, err := decodeIssue([]byte(liveIssueJSON), 1)
	if err != nil {
		t.Fatal(err)
	}
	if info.Number != 1 || info.Title != "interactive pr list" {
		t.Fatalf("got %+v", info)
	}
	if got := issueBranch(info.Number, info.Title); got != "1-interactive-pr-list" {
		t.Errorf("branch: got %q, want 1-interactive-pr-list", got)
	}
}

func TestDecodePullRequestFromLiveSameRepoPayload(t *testing.T) {
	info, err := decodePullRequest([]byte(liveSameRepoPRJSON), 14707)
	if err != nil {
		t.Fatal(err)
	}
	if info.IsCrossRepository {
		t.Error("this pull request is not from a fork")
	}
	branch := prBranch(info)
	if branch != "dependabot/github_actions/goreleaser/goreleaser-action-7.3.0" {
		t.Errorf("branch: got %q", branch)
	}
	if got := worktreePathFor(branch); strings.Contains(got, "/") {
		t.Errorf("the worktree path must be flat, got %q", got)
	}
}

func TestDecodePullRequestFromLiveForkPayload(t *testing.T) {
	info, err := decodePullRequest([]byte(liveCrossRepoPRJSON), 14710)
	if err != nil {
		t.Fatal(err)
	}
	if !info.IsCrossRepository {
		t.Error("this pull request comes from a fork")
	}
	if got := prBranch(info); got != "pr-14710" {
		t.Errorf("branch: got %q, want pr-14710", got)
	}
}

func TestDecodePullRequestWithoutAHeadBranch(t *testing.T) {
	if _, err := decodePullRequest([]byte(`{"number":3}`), 3); err == nil {
		t.Fatal("a pull request with no head branch must be refused")
	}
}

func TestDecodeIssueRejectsGarbage(t *testing.T) {
	if _, err := decodeIssue([]byte("not json"), 1); err == nil {
		t.Fatal("expected a decode error")
	}
}

func TestFetchPullRequestRefBringsAForkHeadIntoALocalBranch(t *testing.T) {
	root, bareDir, defaultBranch := setupProject(t)
	source := filepath.Join(filepath.Dir(root), "source")

	// Stand in for a fork's head: a commit reachable only through
	// refs/pull/7/head on the remote.
	git(t, source, "checkout", "-q", "-b", "contributor")
	if err := os.WriteFile(filepath.Join(source, "fork.txt"), []byte("x\n"), 0644); err != nil {
		t.Fatal(err)
	}
	git(t, source, "add", "fork.txt")
	git(t, source, "commit", "-m", "from the fork")
	git(t, source, "update-ref", "refs/pull/7/head", "refs/heads/contributor")
	git(t, source, "checkout", "-q", defaultBranch)
	git(t, source, "branch", "-D", "contributor")

	info := pullRequestInfo{Number: 7, HeadRefName: "patch-1", IsCrossRepository: true}
	branch := prBranch(info)
	if err := fetchPullRequestRef(bareDir, info, branch); err != nil {
		t.Fatal(err)
	}

	if out := git(t, bareDir, "rev-parse", "--verify", "refs/heads/pr-7"); out == "" {
		t.Fatal("expected refs/heads/pr-7 to exist")
	}
	files := git(t, bareDir, "ls-tree", "--name-only", "refs/heads/pr-7")
	if !strings.Contains(files, "fork.txt") {
		t.Errorf("the fork commit did not land: %q", files)
	}
}

func TestFetchPullRequestRefUpdatesTheRemoteTrackingRef(t *testing.T) {
	root, bareDir, defaultBranch := setupProject(t)
	source := filepath.Join(filepath.Dir(root), "source")

	git(t, source, "checkout", "-q", "-b", "feat/auth")
	if err := os.WriteFile(filepath.Join(source, "auth.txt"), []byte("x\n"), 0644); err != nil {
		t.Fatal(err)
	}
	git(t, source, "add", "auth.txt")
	git(t, source, "commit", "-m", "add auth")
	git(t, source, "checkout", "-q", defaultBranch)

	info := pullRequestInfo{Number: 9, HeadRefName: "feat/auth"}
	if err := fetchPullRequestRef(bareDir, info, prBranch(info)); err != nil {
		t.Fatal(err)
	}

	if out := git(t, bareDir, "rev-parse", "--verify", "refs/remotes/origin/feat/auth"); out == "" {
		t.Fatal("expected refs/remotes/origin/feat/auth to exist")
	}
	if refExists(bareDir, "refs/heads/feat/auth") {
		t.Error("a same-repository head must not create a local branch before the worktree is added")
	}

	args, err := resolveWorktreeAddArgs(bareDir, "feat/auth", filepath.Join(root, "feat-auth"), "")
	if err != nil {
		t.Fatal(err)
	}
	joined := strings.Join(args, " ")
	if !strings.Contains(joined, "--track") || !strings.Contains(joined, "origin/feat/auth") {
		t.Errorf("the fetched head should be tracked: %v", args)
	}
}

func TestOriginSlugReadsTheConfiguredRemote(t *testing.T) {
	_, bareDir, _ := setupProject(t)
	git(t, bareDir, "remote", "set-url", "origin", "git@github.com:rtalexk/dotfiles.git")

	slug, err := originSlug(bareDir)
	if err != nil {
		t.Fatal(err)
	}
	if slug != "rtalexk/dotfiles" {
		t.Errorf("got %q, want rtalexk/dotfiles", slug)
	}
}
