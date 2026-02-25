package utils

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

type WorktreeInfo struct {
	Path    string
	Root    string
	Branch  string
	Session string
}

func ListWorktrees(bareDir, projectRoot string, project *Project) ([]WorktreeInfo, error) {
	out, err := exec.Command("git", "-C", bareDir, "worktree", "list", "--porcelain").Output()
	if err != nil {
		return nil, fmt.Errorf("failed to list worktrees: %w", err)
	}

	root := resolveRoot(projectRoot)

	var result []WorktreeInfo
	for _, block := range strings.Split(strings.TrimSpace(string(out)), "\n\n") {
		info, skip := parseWorktreeBlock(block, projectRoot, root, project)
		if skip {
			continue
		}
		result = append(result, info)
	}
	return result, nil
}

func resolveRoot(projectRoot string) string {
	projectsDir := os.Getenv("PROJECTS")
	if projectsDir == "" {
		return projectRoot
	}
	rel, err := filepath.Rel(projectsDir, projectRoot)
	if err != nil || strings.HasPrefix(rel, "..") {
		return projectRoot
	}
	return rel
}

func parseWorktreeBlock(block, projectRoot, root string, project *Project) (WorktreeInfo, bool) {
	var wtPath, branchRef string
	isBare := false
	isDetached := false

	for _, line := range strings.Split(block, "\n") {
		switch {
		case strings.HasPrefix(line, "worktree "):
			wtPath = strings.TrimPrefix(line, "worktree ")
		case strings.HasPrefix(line, "branch "):
			branchRef = strings.TrimPrefix(line, "branch ")
		case line == "bare":
			isBare = true
		case line == "detached":
			isDetached = true
		}
	}

	if isBare || wtPath == "" {
		return WorktreeInfo{}, true
	}

	rel, err := filepath.Rel(projectRoot, wtPath)
	if err != nil {
		return WorktreeInfo{}, true
	}

	branch := shortBranch(branchRef)
	if isDetached {
		branch = "HEAD"
	}

	return WorktreeInfo{
		Path:    rel,
		Root:    root,
		Branch:  branch,
		Session: project.SessionName(rel),
	}, false
}

func shortBranch(ref string) string {
	if ref == "" {
		return ""
	}
	parts := strings.SplitN(ref, "/", 3)
	if len(parts) == 3 {
		return parts[2]
	}
	return ref
}
