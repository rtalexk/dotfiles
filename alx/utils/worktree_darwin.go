//go:build darwin

package utils

import (
	"os"
	"syscall"
	"time"
)

func statCreatedAt(fi os.FileInfo) time.Time {
	st, ok := fi.Sys().(*syscall.Stat_t)
	if !ok {
		return time.Time{}
	}
	return time.Unix(st.Birthtimespec.Sec, st.Birthtimespec.Nsec)
}
