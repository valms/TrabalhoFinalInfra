package server

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"testing"
)

func TestCRUDAndPersistence(t *testing.T) {
	path := filepath.Join(t.TempDir(), "tasks.db")
	store, err := Open(path)
	if err != nil {
		t.Fatal(err)
	}
	handler := Handler(store)
	request := func(method, path, body string, want int) *httptest.ResponseRecorder {
		t.Helper()
		r := httptest.NewRecorder()
		handler.ServeHTTP(r, httptest.NewRequest(method, path, strings.NewReader(body)))
		if r.Code != want {
			t.Fatalf("%s %s: got %d, want %d: %s", method, path, r.Code, want, r.Body.String())
		}
		return r
	}
	request("GET", "/health", "", http.StatusOK)
	request("GET", "/ready", "", http.StatusOK)
	request("POST", "/tasks", `{"title":"   "}`, http.StatusBadRequest)
	r := request("POST", "/tasks", `{"title":"Study Terraform"}`, http.StatusCreated)
	var created Task
	if err := json.Unmarshal(r.Body.Bytes(), &created); err != nil {
		t.Fatal(err)
	}
	if created.ID != 1 || created.Title != "Study Terraform" {
		t.Fatalf("unexpected task: %+v", created)
	}
	request("GET", "/tasks/1", "", http.StatusOK)
	request("PUT", "/tasks/1", `{"title":"Study EKS","completed":true}`, http.StatusOK)
	if err := store.Close(); err != nil {
		t.Fatal(err)
	}
	store, err = Open(path)
	if err != nil {
		t.Fatal(err)
	}
	defer store.Close()
	handler = Handler(store)
	r = request("GET", "/tasks", "", http.StatusOK)
	var tasks []Task
	if err := json.Unmarshal(r.Body.Bytes(), &tasks); err != nil {
		t.Fatal(err)
	}
	if len(tasks) != 1 || tasks[0].Title != "Study EKS" || !tasks[0].Completed {
		t.Fatalf("not persisted: %+v", tasks)
	}
	request("DELETE", "/tasks/1", "", http.StatusNoContent)
	request("GET", "/tasks/1", "", http.StatusNotFound)
	request("DELETE", "/tasks/1", "", http.StatusNotFound)
	request("GET", "/tasks/nope", "", http.StatusBadRequest)
}

type failingStore struct {
	TaskStore
}

func (failingStore) Ping(context.Context) error           { return errors.New("offline") }
func (failingStore) List(context.Context) ([]Task, error) { return nil, errors.New("offline") }

func TestHandlerUsesStoreContract(t *testing.T) {
	handler := Handler(failingStore{})
	for _, tc := range []struct {
		path string
		want int
	}{
		{path: "/health", want: http.StatusOK},
		{path: "/ready", want: http.StatusServiceUnavailable},
		{path: "/tasks", want: http.StatusInternalServerError},
	} {
		r := httptest.NewRecorder()
		handler.ServeHTTP(r, httptest.NewRequest(http.MethodGet, tc.path, nil))
		if r.Code != tc.want {
			t.Errorf("GET %s: got %d, want %d", tc.path, r.Code, tc.want)
		}
	}
}
