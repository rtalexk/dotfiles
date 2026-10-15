package worktree

import (
	"encoding/json"
	"fmt"
	"os/exec"
	"strconv"
	"strings"
)

const branchSlugMaxLen = 50

type issueInfo struct {
	Number int    `json:"number"`
	Title  string `json:"title"`
}

type pullRequestInfo struct {
	Number            int    `json:"number"`
	HeadRefName       string `json:"headRefName"`
	IsCrossRepository bool   `json:"isCrossRepository"`
	State             string `json:"state"`
}

// repoSlug turns an origin URL into "owner/name" so gh can be pointed at the
// repository explicitly, independent of the working directory.
func repoSlug(originURL string) (string, error) {
	url := strings.TrimSpace(originURL)
	url = strings.TrimSuffix(url, ".git")
	switch {
	case strings.HasPrefix(url, "git@"):
		_, path, found := strings.Cut(url, ":")
		if !found {
			return "", fmt.Errorf("cannot read owner/name from origin URL %q", originURL)
		}
		url = path
	case strings.Contains(url, "://"):
		_, rest, _ := strings.Cut(url, "://")
		_, path, found := strings.Cut(rest, "/")
		if !found {
			return "", fmt.Errorf("cannot read owner/name from origin URL %q", originURL)
		}
		url = path
	}

	parts := strings.Split(strings.Trim(url, "/"), "/")
	if len(parts) < 2 {
		return "", fmt.Errorf("cannot read owner/name from origin URL %q", originURL)
	}
	owner, name := parts[len(parts)-2], parts[len(parts)-1]
	if owner == "" || name == "" {
		return "", fmt.Errorf("cannot read owner/name from origin URL %q", originURL)
	}
	return owner + "/" + name, nil
}

func originSlug(bareDir string) (string, error) {
	out, err := exec.Command("git", "-C", bareDir, "remote", "get-url", "origin").Output()
	if err != nil {
		return "", fmt.Errorf("failed to read the origin URL: %w", err)
	}
	return repoSlug(string(out))
}

func ghView(slug, kind string, number int, fields string) ([]byte, error) {
	out, err := exec.Command("gh", kind, "view", strconv.Itoa(number),
		"--repo", slug, "--json", fields).Output()
	if err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok && len(exitErr.Stderr) > 0 {
			return nil, fmt.Errorf("gh %s view %d: %s", kind, number, strings.TrimSpace(string(exitErr.Stderr)))
		}
		return nil, fmt.Errorf("gh %s view %d: %w", kind, number, err)
	}
	return out, nil
}

func fetchIssue(bareDir string, number int) (issueInfo, error) {
	slug, err := originSlug(bareDir)
	if err != nil {
		return issueInfo{}, err
	}
	out, err := ghView(slug, "issue", number, "number,title")
	if err != nil {
		return issueInfo{}, err
	}
	return decodeIssue(out, number)
}

func decodeIssue(out []byte, number int) (issueInfo, error) {
	var info issueInfo
	if err := json.Unmarshal(out, &info); err != nil {
		return issueInfo{}, fmt.Errorf("could not read issue %d: %w", number, err)
	}
	if info.Number == 0 {
		info.Number = number
	}
	return info, nil
}

func fetchPullRequest(bareDir string, number int) (pullRequestInfo, error) {
	slug, err := originSlug(bareDir)
	if err != nil {
		return pullRequestInfo{}, err
	}
	out, err := ghView(slug, "pr", number, "number,headRefName,isCrossRepository,state")
	if err != nil {
		return pullRequestInfo{}, err
	}
	return decodePullRequest(out, number)
}

func decodePullRequest(out []byte, number int) (pullRequestInfo, error) {
	var info pullRequestInfo
	if err := json.Unmarshal(out, &info); err != nil {
		return pullRequestInfo{}, fmt.Errorf("could not read pull request %d: %w", number, err)
	}
	if info.HeadRefName == "" {
		return pullRequestInfo{}, fmt.Errorf("pull request %d has no head branch", number)
	}
	if info.Number == 0 {
		info.Number = number
	}
	return info, nil
}

// issueBranch names the branch for an issue the way `gh issue develop` does.
func issueBranch(number int, title string) string {
	slug := slugify(title)
	if slug == "" {
		return fmt.Sprintf("%d-issue", number)
	}
	return fmt.Sprintf("%d-%s", number, slug)
}

// prBranch keeps a same-repository head branch as it is, and gives a fork's
// head a local name that cannot collide with a branch of our own.
func prBranch(info pullRequestInfo) string {
	if info.IsCrossRepository {
		return fmt.Sprintf("pr-%d", info.Number)
	}
	return info.HeadRefName
}

// prFetchRefspec pulls a fork's head straight into a local branch, and a
// same-repository head into its remote-tracking ref so --track works.
func prFetchRefspec(info pullRequestInfo, branch string) string {
	if info.IsCrossRepository {
		return fmt.Sprintf("+refs/pull/%d/head:refs/heads/%s", info.Number, branch)
	}
	return fmt.Sprintf("+refs/heads/%s:refs/remotes/origin/%s", info.HeadRefName, info.HeadRefName)
}

func worktreePathFor(branch string) string {
	return strings.ReplaceAll(branch, "/", "-")
}

func slugify(s string) string {
	var b strings.Builder
	pendingDash := false
	for _, r := range strings.ToLower(s) {
		switch {
		case (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9'):
			if pendingDash && b.Len() > 0 {
				b.WriteByte('-')
			}
			pendingDash = false
			b.WriteRune(r)
		default:
			pendingDash = true
		}
		if b.Len() >= branchSlugMaxLen {
			break
		}
	}
	return strings.Trim(b.String(), "-")
}
