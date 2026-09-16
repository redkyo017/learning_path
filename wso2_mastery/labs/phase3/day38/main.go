package main

import (
	"encoding/json"
	"fmt"
	"log/slog"
	"sync"
	"time"
)

type EventType string

const (
	EventAPICreated    EventType = "API_CREATED"
	EventAPIPublished  EventType = "API_PUBLISHED"
	EventAPIDeprecated EventType = "API_DEPRECATED"
	EventAPIRetired    EventType = "API_RETIRED"
	EventSubCreated    EventType = "SUBSCRIPTION_CREATED"
	EventSubRemoved    EventType = "SUBSCRIPTION_REMOVED"
)

type Event struct {
	Type      EventType       `json:"type"`
	Timestamp time.Time       `json:"timestamp"`
	Payload   json.RawMessage `json:"payload"`
}

func NewEvent(et EventType, payload any) Event {
	raw, _ := json.Marshal(payload)
	return Event{Type: et, Timestamp: time.Now().UTC(), Payload: raw}
}

const subBufSize = 32

type EventBus struct {
	mu     sync.RWMutex
	subs   map[EventType][]chan Event
	allSub []chan Event
}

func NewEventBus() *EventBus {
	return &EventBus{subs: make(map[EventType][]chan Event)}
}

func (b *EventBus) Subscribe(et EventType) (<-chan Event, func()) {
	ch := make(chan Event, subBufSize)
	b.mu.Lock()
	b.subs[et] = append(b.subs[et], ch)
	b.mu.Unlock()
	return ch, func() {
		b.mu.Lock()
		chs := b.subs[et]
		for i, c := range chs {
			if c == ch {
				b.subs[et] = append(chs[:i], chs[i+1:]...)
				break
			}
		}
		b.mu.Unlock()
	}
}

func (b *EventBus) SubscribeAll() (<-chan Event, func()) {
	ch := make(chan Event, subBufSize)
	b.mu.Lock()
	b.allSub = append(b.allSub, ch)
	b.mu.Unlock()
	return ch, func() {
		b.mu.Lock()
		for i, c := range b.allSub {
			if c == ch {
				b.allSub = append(b.allSub[:i], b.allSub[i+1:]...)
				break
			}
		}
		b.mu.Unlock()
	}
}

// Publish is non-blocking: drops and logs if a subscriber's buffer is full.
func (b *EventBus) Publish(e Event) {
	b.mu.RLock()
	typed := make([]chan Event, len(b.subs[e.Type]))
	copy(typed, b.subs[e.Type])
	all := make([]chan Event, len(b.allSub))
	copy(all, b.allSub)
	b.mu.RUnlock()
	for _, ch := range append(typed, all...) {
		select {
		case ch <- e:
		default:
			slog.Warn("event bus: buffer full, dropping event", "type", e.Type)
		}
	}
}

func main() {
	bus := NewEventBus()

	// Simulated GW subscriber: listens for API_PUBLISHED events only
	apiCh, unsub := bus.Subscribe(EventAPIPublished)
	defer unsub()

	go func() {
		for e := range apiCh {
			var payload map[string]any
			json.Unmarshal(e.Payload, &payload)
			slog.Info("GW received API_PUBLISHED", "context", payload["context"], "version", payload["version"])
		}
	}()

	// All-events subscriber (simulates SSE streaming goroutine)
	allCh, unsubAll := bus.SubscribeAll()
	defer unsubAll()

	go func() {
		for e := range allCh {
			slog.Info("SSE stream", "type", e.Type)
		}
	}()

	// Simulate CP publishing
	bus.Publish(NewEvent(EventAPIPublished, map[string]any{
		"id": "abc123", "name": "PetStore", "context": "/petstore/v1", "version": "1.0",
		"tiers": []string{"Gold", "Silver"},
	}))
	bus.Publish(NewEvent(EventSubCreated, map[string]any{
		"apiId": "abc123", "appName": "PetApp", "tier": "Gold",
	}))

	time.Sleep(100 * time.Millisecond)
	fmt.Println("Event bus demo complete.")
}
