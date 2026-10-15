package worktree

import "testing"

func TestRepoSlug(t *testing.T) {
	cases := []struct {
		url  string
		want string
	}{
		{"git@github.com:rtalexk/dotfiles.git", "rtalexk/dotfiles"},
		{"git@github.com:rtalexk/dotfiles", "rtalexk/dotfiles"},
		{"https://github.com/rtalexk/dotfiles.git", "rtalexk/dotfiles"},
		{"https://github.com/rtalexk/dotfiles", "rtalexk/dotfiles"},
		{"ssh://git@github.com/rtalexk/dotfiles.git", "rtalexk/dotfiles"},
		{"https://github.com/rtalexk/dotfiles/\n", "rtalexk/dotfiles"},
		{"git@github.com:org/team/repo.git", "team/repo"},
	}

	for _, c := range cases {
		got, err := repoSlug(c.url)
		if err != nil {
			t.Errorf("%s: %v", c.url, err)
			continue
		}
		if got != c.want {
			t.Errorf("%s: got %q, want %q", c.url, got, c.want)
		}
	}
}

func TestRepoSlugRejectsUnparseableURL(t *testing.T) {
	for _, url := range []string{"", "dotfiles", "git@github.com", "https://github.com/"} {
		if got, err := repoSlug(url); err == nil {
			t.Errorf("%q: expected an error, got %q", url, got)
		}
	}
}

func TestSlugify(t *testing.T) {
	cases := []struct {
		in   string
		want string
	}{
		{"Add login page", "add-login-page"},
		{"  spaces   collapse  ", "spaces-collapse"},
		{"Fix: the C++ parser (again)!", "fix-the-c-parser-again"},
		{"already-kebab", "already-kebab"},
		{"Café ñandú", "caf-and"},
		{"123 numbers 456", "123-numbers-456"},
		{"!!!", ""},
		{"", ""},
	}

	for _, c := range cases {
		if got := slugify(c.in); got != c.want {
			t.Errorf("slugify(%q): got %q, want %q", c.in, got, c.want)
		}
	}
}

func TestSlugifyTruncates(t *testing.T) {
	long := "this title is deliberately far longer than the slug limit allows for a branch"
	got := slugify(long)
	if len(got) > branchSlugMaxLen {
		t.Errorf("slug is %d bytes, want at most %d: %q", len(got), branchSlugMaxLen, got)
	}
	if got == "" {
		t.Error("a long title must still produce a slug")
	}
}

func TestIssueBranch(t *testing.T) {
	if got := issueBranch(42, "Add login page"); got != "42-add-login-page" {
		t.Errorf("got %q, want 42-add-login-page", got)
	}
}

func TestIssueBranchWithUnslugifiableTitle(t *testing.T) {
	if got := issueBranch(7, "???"); got != "7-issue" {
		t.Errorf("got %q, want 7-issue", got)
	}
}

func TestPRBranchSameRepository(t *testing.T) {
	info := pullRequestInfo{Number: 9, HeadRefName: "feat/auth"}
	if got := prBranch(info); got != "feat/auth" {
		t.Errorf("got %q, want feat/auth", got)
	}
}

func TestPRBranchFromFork(t *testing.T) {
	info := pullRequestInfo{Number: 9, HeadRefName: "patch-1", IsCrossRepository: true}
	if got := prBranch(info); got != "pr-9" {
		t.Errorf("got %q, want pr-9", got)
	}
}

func TestPRFetchRefspecSameRepository(t *testing.T) {
	info := pullRequestInfo{Number: 9, HeadRefName: "feat/auth"}
	want := "+refs/heads/feat/auth:refs/remotes/origin/feat/auth"
	if got := prFetchRefspec(info, prBranch(info)); got != want {
		t.Errorf("got %q, want %q", got, want)
	}
}

func TestPRFetchRefspecFromFork(t *testing.T) {
	info := pullRequestInfo{Number: 9, HeadRefName: "patch-1", IsCrossRepository: true}
	want := "+refs/pull/9/head:refs/heads/pr-9"
	if got := prFetchRefspec(info, prBranch(info)); got != want {
		t.Errorf("got %q, want %q", got, want)
	}
}

func TestWorktreePathFor(t *testing.T) {
	if got := worktreePathFor("feat/auth/login"); got != "feat-auth-login" {
		t.Errorf("got %q, want feat-auth-login", got)
	}
}
