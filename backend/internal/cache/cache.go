// Package cache holds cached HTTP answers in memory and in Postgres.
package cache

import (
	"container/list"
	"context"
	"sync"
	"time"
)

// Entry is one cached upstream answer.
type Entry struct {
	Status    int
	Body      []byte
	FetchedAt time.Time
	ExpiresAt time.Time
}

// Store is a key/value cache layer.
type Store interface {
	Get(ctx context.Context, key string) (Entry, bool, error)
	Set(ctx context.Context, key string, e Entry) error
}

// Memory is a fixed-size LRU store.
type Memory struct {
	mu    sync.Mutex
	cap   int
	order *list.List
	items map[string]*list.Element
}

type memItem struct {
	key string
	e   Entry
}

func NewMemory(capacity int) *Memory {
	return &Memory{cap: capacity, order: list.New(), items: make(map[string]*list.Element)}
}

func (m *Memory) Get(_ context.Context, key string) (Entry, bool, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	el, ok := m.items[key]
	if !ok {
		return Entry{}, false, nil
	}
	m.order.MoveToFront(el)
	return el.Value.(*memItem).e, true, nil
}

func (m *Memory) Set(_ context.Context, key string, e Entry) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if el, ok := m.items[key]; ok {
		el.Value.(*memItem).e = e
		m.order.MoveToFront(el)
		return nil
	}
	m.items[key] = m.order.PushFront(&memItem{key, e})
	for m.order.Len() > m.cap {
		old := m.order.Back()
		m.order.Remove(old)
		delete(m.items, old.Value.(*memItem).key)
	}
	return nil
}

func (m *Memory) Len() int {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.order.Len()
}
