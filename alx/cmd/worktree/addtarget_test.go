package worktree

import "testing"

func TestValidateAddArgsAcceptsPlainForms(t *testing.T) {
	cases := [][]string{{"feat-auth"}, {"feat-auth", "feat/auth"}}
	for _, args := range cases {
		if err := validateAddArgs(args, 0, 0); err != nil {
			t.Errorf("%v: %v", args, err)
		}
	}
}

func TestValidateAddArgsRejectsBothIssueAndPR(t *testing.T) {
	if err := validateAddArgs(nil, 1, 2); err == nil {
		t.Fatal("--issue and --pr together must be refused")
	}
}

func TestValidateAddArgsRejectsNegativeNumbers(t *testing.T) {
	if err := validateAddArgs(nil, -1, 0); err == nil {
		t.Fatal("a negative --issue must be refused")
	}
	if err := validateAddArgs(nil, 0, -1); err == nil {
		t.Fatal("a negative --pr must be refused")
	}
}

func TestValidateAddArgsRequiresAPathWithoutIssueOrPR(t *testing.T) {
	if err := validateAddArgs(nil, 0, 0); err == nil {
		t.Fatal("a bare add must be refused")
	}
}

func TestValidateAddArgsRejectsAnExplicitBranchWithIssue(t *testing.T) {
	if err := validateAddArgs([]string{"dir", "branch"}, 42, 0); err == nil {
		t.Fatal("--issue already names the branch")
	}
}

func TestValidateAddArgsAllowsAPathWithIssue(t *testing.T) {
	if err := validateAddArgs([]string{"dir"}, 42, 0); err != nil {
		t.Fatal(err)
	}
}

func TestResolveAddTargetPathOnly(t *testing.T) {
	path, branch, err := resolveAddTarget("", []string{"feat-auth"}, 0, 0)
	if err != nil {
		t.Fatal(err)
	}
	if path != "feat-auth" || branch != "feat-auth" {
		t.Errorf("got path=%q branch=%q, want both feat-auth", path, branch)
	}
}

func TestResolveAddTargetPathAndBranch(t *testing.T) {
	path, branch, err := resolveAddTarget("", []string{"feat-auth", "feat/auth"}, 0, 0)
	if err != nil {
		t.Fatal(err)
	}
	if path != "feat-auth" || branch != "feat/auth" {
		t.Errorf("got path=%q branch=%q", path, branch)
	}
}

func TestResolveAddTargetPropagatesValidationError(t *testing.T) {
	if _, _, err := resolveAddTarget("", nil, 0, 0); err == nil {
		t.Fatal("expected the validation error to surface")
	}
}
