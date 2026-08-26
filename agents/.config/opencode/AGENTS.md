## Writing Style

Never use the em dash. Replace it with a comma, a connector, parentheses, a colon, or two sentences.

## Worktrees

Always use `alx worktree` (alias: `alx wt`) to create and remove worktrees. Never use raw `git worktree` commands.

```bash
alx worktree add <path> [branch]
alx worktree remove <name>
alx worktree remove <name> --force
alx worktree remove <name> --fuzzy
alx worktree list
alx worktree list --name-only
```

`add` creates the worktree directory and a paired tmux session. `remove` tears down both. `--force` is required when the branch is unmerged or has untracked or modified files.

## Commits

When creating git commits, always use the `conventional-commit` skill via the Skill tool instead of running `git commit` directly. Default to `atomic` mode unless the user specifies another mode.
