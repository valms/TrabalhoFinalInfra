package main

import (
	"net"
	"path/filepath"
	"testing"
)

func TestRunReportsBindFailure(t *testing.T) {
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer listener.Close()
	t.Setenv("DB_PATH", filepath.Join(t.TempDir(), "tasks.db"))
	t.Setenv("LISTEN_ADDR", listener.Addr().String())
	if err := run(); err == nil {
		t.Fatal("expected occupied port to fail startup")
	}
}
