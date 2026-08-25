package server

import (
	"context"
	"database/sql"
	"time"

	_ "modernc.org/sqlite"
)

// SQLiteStore owns the database connection and task persistence.
type SQLiteStore struct{ db *sql.DB }

// Open creates a SQLite store. The caller closes it when shutting down.
func Open(path string) (*SQLiteStore, error) {
	db, err := sql.Open("sqlite", path)
	if err != nil {
		return nil, err
	}
	db.SetMaxOpenConns(1)
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if _, err = db.ExecContext(ctx, `CREATE TABLE IF NOT EXISTS tasks (
		id INTEGER PRIMARY KEY, title TEXT NOT NULL, completed INTEGER NOT NULL DEFAULT 0,
		created_at TEXT NOT NULL)`); err != nil {
		db.Close()
		return nil, err
	}
	return &SQLiteStore{db: db}, nil
}

func (s *SQLiteStore) Close() error { return s.db.Close() }

func (s *SQLiteStore) Ping(ctx context.Context) error { return s.db.PingContext(ctx) }

func (s *SQLiteStore) Create(ctx context.Context, title string) (Task, error) {
	now := time.Now().UTC()
	result, err := s.db.ExecContext(ctx, "INSERT INTO tasks (title, created_at) VALUES (?, ?)", title, now.Format(time.RFC3339Nano))
	if err != nil {
		return Task{}, err
	}
	id, err := result.LastInsertId()
	if err != nil {
		return Task{}, err
	}
	return Task{ID: id, Title: title, CreatedAt: now}, nil
}

func (s *SQLiteStore) List(ctx context.Context) ([]Task, error) {
	rows, err := s.db.QueryContext(ctx, "SELECT id, title, completed, created_at FROM tasks ORDER BY id")
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	tasks := []Task{}
	for rows.Next() {
		task, err := scan(rows)
		if err != nil {
			return nil, err
		}
		tasks = append(tasks, task)
	}
	return tasks, rows.Err()
}

func (s *SQLiteStore) Get(ctx context.Context, id int64) (Task, error) {
	return scan(s.db.QueryRowContext(ctx, "SELECT id, title, completed, created_at FROM tasks WHERE id = ?", id))
}

func (s *SQLiteStore) Update(ctx context.Context, id int64, title string, completed bool) (Task, error) {
	result, err := s.db.ExecContext(ctx, "UPDATE tasks SET title = ?, completed = ? WHERE id = ?", title, completed, id)
	if err != nil {
		return Task{}, err
	}
	n, err := result.RowsAffected()
	if err != nil {
		return Task{}, err
	}
	if n == 0 {
		return Task{}, sql.ErrNoRows
	}
	return s.Get(ctx, id)
}

func (s *SQLiteStore) Delete(ctx context.Context, id int64) (bool, error) {
	result, err := s.db.ExecContext(ctx, "DELETE FROM tasks WHERE id = ?", id)
	if err != nil {
		return false, err
	}
	n, err := result.RowsAffected()
	return n != 0, err
}

type scanner interface{ Scan(...any) error }

func scan(row scanner) (Task, error) {
	var task Task
	var created string
	if err := row.Scan(&task.ID, &task.Title, &task.Completed, &created); err != nil {
		return task, err
	}
	t, err := time.Parse(time.RFC3339Nano, created)
	task.CreatedAt = t
	return task, err
}
