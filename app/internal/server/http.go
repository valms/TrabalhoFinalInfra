package server

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"strings"
)

var Version = "dev"

// TaskStore is the persistence contract required by HTTP handlers.
type TaskStore interface {
	Ping(context.Context) error
	Create(context.Context, string) (Task, error)
	List(context.Context) ([]Task, error)
	Get(context.Context, int64) (Task, error)
	Update(context.Context, int64, string, bool) (Task, error)
	Delete(context.Context, int64) (bool, error)
}

// Handler depends on its storage contract, not on SQLite.
func Handler(store TaskStore) http.Handler {
	h := &taskHandler{store: store}
	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusOK) })
	mux.HandleFunc("GET /ready", h.ready)
	mux.HandleFunc("GET /version", func(w http.ResponseWriter, _ *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"version": Version})
	})
	mux.HandleFunc("POST /tasks", h.create)
	mux.HandleFunc("GET /tasks", h.list)
	mux.HandleFunc("GET /tasks/{id}", h.get)
	mux.HandleFunc("PUT /tasks/{id}", h.update)
	mux.HandleFunc("DELETE /tasks/{id}", h.delete)
	return mux
}

type taskHandler struct{ store TaskStore }

func (h *taskHandler) ready(w http.ResponseWriter, r *http.Request) {
	if err := h.store.Ping(r.Context()); err != nil {
		http.Error(w, "database unavailable", http.StatusServiceUnavailable)
		return
	}
	w.WriteHeader(http.StatusOK)
}

func (h *taskHandler) create(w http.ResponseWriter, r *http.Request) {
	var input struct {
		Title string `json:"title"`
	}
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 4096)).Decode(&input); err != nil || strings.TrimSpace(input.Title) == "" {
		http.Error(w, "valid title required", http.StatusBadRequest)
		return
	}
	task, err := h.store.Create(r.Context(), strings.TrimSpace(input.Title))
	if err != nil {
		serverError(w)
		return
	}
	writeJSON(w, http.StatusCreated, task)
}

func (h *taskHandler) list(w http.ResponseWriter, r *http.Request) {
	tasks, err := h.store.List(r.Context())
	if err != nil {
		serverError(w)
		return
	}
	writeJSON(w, http.StatusOK, tasks)
}

func (h *taskHandler) get(w http.ResponseWriter, r *http.Request) {
	id, ok := parseID(w, r)
	if !ok {
		return
	}
	task, err := h.store.Get(r.Context(), id)
	if errors.Is(err, sql.ErrNoRows) {
		http.NotFound(w, r)
		return
	}
	if err != nil {
		serverError(w)
		return
	}
	writeJSON(w, http.StatusOK, task)
}

func (h *taskHandler) update(w http.ResponseWriter, r *http.Request) {
	id, ok := parseID(w, r)
	if !ok {
		return
	}
	var input struct {
		Title     string `json:"title"`
		Completed *bool  `json:"completed"`
	}
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 4096)).Decode(&input); err != nil || strings.TrimSpace(input.Title) == "" || input.Completed == nil {
		http.Error(w, "title and completed required", http.StatusBadRequest)
		return
	}
	task, err := h.store.Update(r.Context(), id, strings.TrimSpace(input.Title), *input.Completed)
	if errors.Is(err, sql.ErrNoRows) {
		http.NotFound(w, r)
		return
	}
	if err != nil {
		serverError(w)
		return
	}
	writeJSON(w, http.StatusOK, task)
}

func (h *taskHandler) delete(w http.ResponseWriter, r *http.Request) {
	id, ok := parseID(w, r)
	if !ok {
		return
	}
	deleted, err := h.store.Delete(r.Context(), id)
	if err != nil {
		serverError(w)
		return
	}
	if !deleted {
		http.NotFound(w, r)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func parseID(w http.ResponseWriter, r *http.Request) (int64, bool) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil || id < 1 {
		http.Error(w, "invalid id", http.StatusBadRequest)
		return 0, false
	}
	return id, true
}

func serverError(w http.ResponseWriter) {
	http.Error(w, "database error", http.StatusInternalServerError)
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}
