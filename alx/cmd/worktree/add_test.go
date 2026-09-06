package worktree

import (
	"os"
	"path/filepath"
	"slices"
	"testing"
)

func TestLinkFileCreatesSymlinkToSource(t *testing.T) {
	tmp := t.TempDir()
	src := filepath.Join(tmp, "src", ".env")
	os.MkdirAll(filepath.Dir(src), 0755)
	os.WriteFile(src, []byte("SECRET=1\n"), 0644)
	dst := filepath.Join(tmp, "wt", "config", ".env")

	if err := linkFile(src, dst); err != nil {
		t.Fatal(err)
	}

	target, err := os.Readlink(dst)
	if err != nil {
		t.Fatalf("dst is not a symlink: %v", err)
	}
	if target != src {
		t.Errorf("link target: got %q, want %q", target, src)
	}
	content, err := os.ReadFile(dst)
	if err != nil {
		t.Fatal(err)
	}
	if string(content) != "SECRET=1\n" {
		t.Errorf("link content: got %q", content)
	}
}

func TestLinkFileReplacesExistingSymlink(t *testing.T) {
	tmp := t.TempDir()
	src := filepath.Join(tmp, ".env")
	os.WriteFile(src, []byte("new\n"), 0644)
	stale := filepath.Join(tmp, "gone")
	dst := filepath.Join(tmp, "wt", ".env")
	os.MkdirAll(filepath.Dir(dst), 0755)
	os.Symlink(stale, dst)

	if err := linkFile(src, dst); err != nil {
		t.Fatal(err)
	}

	target, err := os.Readlink(dst)
	if err != nil {
		t.Fatalf("dst is not a symlink: %v", err)
	}
	if target != src {
		t.Errorf("link target: got %q, want %q", target, src)
	}
}

func TestLinkFileRefusesToClobberRegularFile(t *testing.T) {
	tmp := t.TempDir()
	src := filepath.Join(tmp, ".env")
	os.WriteFile(src, []byte("new\n"), 0644)
	dst := filepath.Join(tmp, "wt", ".env")
	os.MkdirAll(filepath.Dir(dst), 0755)
	os.WriteFile(dst, []byte("existing\n"), 0644)

	if err := linkFile(src, dst); err == nil {
		t.Fatal("expected error when dst is a regular file, got nil")
	}

	content, err := os.ReadFile(dst)
	if err != nil {
		t.Fatal(err)
	}
	if string(content) != "existing\n" {
		t.Errorf("dst was modified: got %q", content)
	}
}

func TestLinkFileErrorsWhenSourceMissing(t *testing.T) {
	tmp := t.TempDir()
	src := filepath.Join(tmp, "nope")
	dst := filepath.Join(tmp, "wt", "nope")

	if err := linkFile(src, dst); err == nil {
		t.Fatal("expected error for missing source, got nil")
	}
	if _, err := os.Lstat(dst); !os.IsNotExist(err) {
		t.Errorf("dst should not exist, Lstat err: %v", err)
	}
}

func TestConnectCommandDetachedReturnsNil(t *testing.T) {
	for _, insideTmux := range []bool{true, false} {
		if cmd := connectCommand("dotf-feat", true, insideTmux); cmd != nil {
			t.Errorf("insideTmux=%v: got %v, want nil", insideTmux, cmd.Args)
		}
	}
}

func TestConnectCommandInsideTmuxSwitchesClient(t *testing.T) {
	cmd := connectCommand("dotf-feat", false, true)
	if cmd == nil {
		t.Fatal("got nil, want a tmux command")
	}

	want := []string{"tmux", "switch-client", "-t", "dotf-feat"}
	if !slices.Equal(cmd.Args, want) {
		t.Errorf("got %v, want %v", cmd.Args, want)
	}
}

func TestConnectCommandOutsideTmuxAttachesSession(t *testing.T) {
	cmd := connectCommand("dotf-feat", false, false)
	if cmd == nil {
		t.Fatal("got nil, want a tmux command")
	}

	want := []string{"tmux", "attach-session", "-t", "dotf-feat"}
	if !slices.Equal(cmd.Args, want) {
		t.Errorf("got %v, want %v", cmd.Args, want)
	}
	if cmd.Stdin != os.Stdin {
		t.Error("attach must inherit stdin")
	}
}
