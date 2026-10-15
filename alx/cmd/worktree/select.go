package worktree

import (
	"alx/utils"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// selectWorktree resolves one worktree by relative path, directory name or
// branch. Name matches an exact relative path first, then a directory name.
func selectWorktree(worktrees []utils.WorktreeInfo, name, branch string) (utils.WorktreeInfo, error) {
	if name != "" && branch != "" {
		return utils.WorktreeInfo{}, fmt.Errorf("--name and --branch are mutually exclusive")
	}

	if branch != "" {
		var hits []utils.WorktreeInfo
		for _, wt := range worktrees {
			if wt.Branch == branch {
				hits = append(hits, wt)
			}
		}
		return exactlyOne(hits, "branch", branch)
	}

	if name == "" {
		return utils.WorktreeInfo{}, fmt.Errorf("no worktree selected")
	}

	want := filepath.Clean(name)
	var byPath, byBase []utils.WorktreeInfo
	for _, wt := range worktrees {
		switch {
		case wt.Path == want:
			byPath = append(byPath, wt)
		case filepath.Base(wt.Path) == want:
			byBase = append(byBase, wt)
		}
	}
	if len(byPath) > 0 {
		return exactlyOne(byPath, "name", name)
	}
	return exactlyOne(byBase, "name", name)
}

func exactlyOne(hits []utils.WorktreeInfo, kind, value string) (utils.WorktreeInfo, error) {
	switch len(hits) {
	case 0:
		return utils.WorktreeInfo{}, fmt.Errorf("no worktree with %s %q", kind, value)
	case 1:
		return hits[0], nil
	}
	paths := make([]string, len(hits))
	for i, wt := range hits {
		paths[i] = wt.Path
	}
	return utils.WorktreeInfo{}, fmt.Errorf("%s %q matches %d worktrees: %s", kind, value, len(hits), strings.Join(paths, ", "))
}

// currentWorktree returns the worktree containing dir, preferring the deepest
// match so a worktree nested inside another still wins.
func currentWorktree(worktrees []utils.WorktreeInfo, dir string) (utils.WorktreeInfo, error) {
	var best utils.WorktreeInfo
	found := false
	for _, wt := range worktrees {
		if wt.AbsPath == "" || !withinDir(wt.AbsPath, dir) {
			continue
		}
		if !found || len(wt.AbsPath) > len(best.AbsPath) {
			best, found = wt, true
		}
	}
	if !found {
		return utils.WorktreeInfo{}, fmt.Errorf("%s is not inside a worktree of this project", dir)
	}
	return best, nil
}

func withinDir(base, target string) bool {
	rel, err := filepath.Rel(base, target)
	if err != nil {
		return false
	}
	return rel == "." || (rel != ".." && !strings.HasPrefix(rel, ".."+string(filepath.Separator)))
}

// resolveWorktree picks the worktree named by the flags, or the one holding the
// working directory when neither flag is set.
func resolveWorktree(worktrees []utils.WorktreeInfo, name, branch string) (utils.WorktreeInfo, error) {
	if name != "" || branch != "" {
		return selectWorktree(worktrees, name, branch)
	}
	cwd, err := os.Getwd()
	if err != nil {
		return utils.WorktreeInfo{}, err
	}
	if real, err := filepath.EvalSymlinks(cwd); err == nil {
		cwd = real
	}
	return currentWorktree(worktrees, cwd)
}
