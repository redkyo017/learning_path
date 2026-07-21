package main

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestCheckURL_OK(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))
	defer srv.Close()

	client := srv.Client()
	r := checkURL(context.Background(), client, srv.URL)
	if r.Err != "" {
		t.Fatalf("unexpected error: %s", r.Err)
	}
	if r.StatusCode != 200 {
		t.Errorf("status = %d, want 200", r.StatusCode)
	}
}

func TestCheckURL_Cancel(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))
	defer srv.Close()

	ctx, cancel := context.WithCancel(context.Background())
	cancel() // cancel immediately

	client := srv.Client()
	r := checkURL(ctx, client, srv.URL)
	if r.Err == "" {
		t.Error("expected error for cancelled context")
	}
}
