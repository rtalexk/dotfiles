//go:build linux

package utils

import (
	"os"
	"syscall"
	"time"
)

// statCreatedAt returns the inode change time as a proxy for creation time.
// Linux does not expose birth time via syscall.Stat_t; Ctim is the closest available.
func statCreatedAt(fi os.FileInfo) time.Time {
	st, ok := fi.Sys().(*syscall.Stat_t)
	if !ok {
		return time.Time{}
	}
	return time.Unix(st.Ctim.Sec, st.Ctim.Nsec)
}
