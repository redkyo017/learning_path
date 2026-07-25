// Tiny event-sourced Order aggregate + a CQRS read-model projector.
//
// Commands (append events):
//
//	go run . place  <order_id> <sku> <qty> <total_cents>
//	go run . pay    <order_id>
//	go run . ship   <order_id> <carrier>
//	go run . cancel <order_id> <reason>
//
// Queries / mechanics:
//
//	go run . state  <order_id>   # rehydrate: FOLD the event stream -> true state
//	go run . project             # incrementally update the read model from the log
//	go run . replay              # TRUNCATE the read model + rebuild from global_seq 0
//	go run . view                # dump the order_status_view read model
//	go run . log                 # dump the raw event store
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"strconv"

	"github.com/jackc/pgx/v5"
)

const dsn = "postgres://postgres:pass@localhost:5432/app"

// State is the folded current state of one Order aggregate.
type State struct {
	Status     string
	TotalCents int64
}

// apply is the FOLD — a PURE function (state, event) -> state. No clocks, no I/O:
// that purity is exactly why replay reproduces state deterministically. This is
// the SOURCE OF TRUTH fold and it handles every event, including Cancelled.
func apply(s State, eventType string, p map[string]any) State {
	switch eventType {
	case "OrderPlaced":
		s.Status = "PLACED"
		if v, ok := p["total_cents"].(float64); ok {
			s.TotalCents = int64(v)
		}
	case "OrderPaid":
		s.Status = "PAID"
	case "OrderShipped":
		s.Status = "SHIPPED"
	case "OrderCancelled":
		s.Status = "CANCELLED"
	}
	return s
}

func main() {
	if len(os.Args) < 2 {
		log.Fatal("usage: see the header of main.go")
	}
	ctx := context.Background()
	conn, err := pgx.Connect(ctx, dsn)
	if err != nil {
		log.Fatalf("connect (is postgres up? see lab/README.md): %v", err)
	}
	defer conn.Close(ctx)

	args := os.Args[2:]
	switch os.Args[1] {
	case "place":
		must(4, args)
		total, _ := strconv.ParseInt(args[3], 10, 64)
		appendEvent(ctx, conn, args[0], "OrderPlaced", map[string]any{
			"sku": args[1], "quantity": atoi(args[2]), "total_cents": total,
		})
	case "pay":
		must(1, args)
		appendEvent(ctx, conn, args[0], "OrderPaid", map[string]any{})
	case "ship":
		must(2, args)
		appendEvent(ctx, conn, args[0], "OrderShipped", map[string]any{"carrier": args[1]})
	case "cancel":
		must(2, args)
		appendEvent(ctx, conn, args[0], "OrderCancelled", map[string]any{"reason": args[1]})
	case "state":
		must(1, args)
		s, ver := loadState(ctx, conn, args[0])
		fmt.Printf("FOLD (true state) %s: status=%s total_cents=%d version=%d\n", args[0], s.Status, s.TotalCents, ver)
	case "project":
		n := project(ctx, conn)
		fmt.Printf("projected %d new event(s) into order_status_view\n", n)
	case "replay":
		mustExec(ctx, conn, "TRUNCATE order_status_view")
		mustExec(ctx, conn, "UPDATE projector_checkpoint SET position = 0 WHERE id = 1")
		n := project(ctx, conn)
		fmt.Printf("REPLAYED: rebuilt read model from %d event(s)\n", n)
	case "view":
		dumpView(ctx, conn)
	case "log":
		dumpLog(ctx, conn)
	default:
		log.Fatalf("unknown command %q", os.Args[1])
	}
}

// appendEvent writes the next event for an aggregate. The read-then-insert of the
// next seq is racy on purpose: UNIQUE(aggregate_id, seq) is the optimistic-
// concurrency guard — two concurrent appends at the same version, one wins.
func appendEvent(ctx context.Context, conn *pgx.Conn, aggID, eventType string, payload map[string]any) {
	var maxSeq int
	if err := conn.QueryRow(ctx, `SELECT COALESCE(MAX(seq),0) FROM events WHERE aggregate_id=$1`, aggID).Scan(&maxSeq); err != nil {
		log.Fatalf("read version: %v", err)
	}
	b, _ := json.Marshal(payload)
	if _, err := conn.Exec(ctx,
		`INSERT INTO events (aggregate_id, seq, event_type, payload) VALUES ($1,$2,$3,$4)`,
		aggID, maxSeq+1, eventType, b); err != nil {
		log.Fatalf("append (optimistic-concurrency conflict?): %v", err)
	}
	fmt.Printf("appended %s v%d to %s\n", eventType, maxSeq+1, aggID)
}

// loadState rehydrates an aggregate by folding its event stream. This is always
// correct — it uses the full `apply`. Compare it to the projection in `view`.
func loadState(ctx context.Context, conn *pgx.Conn, aggID string) (State, int) {
	rows, err := conn.Query(ctx, `SELECT seq, event_type, payload FROM events WHERE aggregate_id=$1 ORDER BY seq`, aggID)
	if err != nil {
		log.Fatalf("load: %v", err)
	}
	defer rows.Close()
	var s State
	var lastSeq int
	for rows.Next() {
		var seq int
		var et string
		var pb []byte
		if err := rows.Scan(&seq, &et, &pb); err != nil {
			log.Fatalf("scan: %v", err)
		}
		var p map[string]any
		_ = json.Unmarshal(pb, &p)
		s = apply(s, et, p)
		lastSeq = seq
	}
	return s, lastSeq
}

type logRow struct {
	globalSeq int64
	aggID     string
	seq       int
	eventType string
	payload   map[string]any
}

// project incrementally updates order_status_view from events after the checkpoint.
func project(ctx context.Context, conn *pgx.Conn) int {
	var pos int64
	if err := conn.QueryRow(ctx, `SELECT position FROM projector_checkpoint WHERE id=1`).Scan(&pos); err != nil {
		log.Fatalf("checkpoint: %v", err)
	}
	// Buffer rows first (pgx conn is single-use while a result set is open).
	rows, err := conn.Query(ctx,
		`SELECT global_seq, aggregate_id, seq, event_type, payload FROM events WHERE global_seq > $1 ORDER BY global_seq`, pos)
	if err != nil {
		log.Fatalf("project query: %v", err)
	}
	var batch []logRow
	for rows.Next() {
		var r logRow
		var pb []byte
		if err := rows.Scan(&r.globalSeq, &r.aggID, &r.seq, &r.eventType, &pb); err != nil {
			log.Fatalf("scan: %v", err)
		}
		_ = json.Unmarshal(pb, &r.payload)
		batch = append(batch, r)
	}
	rows.Close()

	var last int64 = pos
	for _, r := range batch {
		applyToView(ctx, conn, r)
		last = r.globalSeq
	}
	if last != pos {
		mustExec(ctx, conn, `UPDATE projector_checkpoint SET position=$1 WHERE id=1`, last)
	}
	return len(batch)
}

// applyToView is the PROJECTOR's event handler. NOTE: this is a SEPARATE handler
// from `apply` — a read model can be shaped differently from the aggregate.
func applyToView(ctx context.Context, conn *pgx.Conn, r logRow) {
	switch r.eventType {
	case "OrderPlaced":
		total := int64(0)
		if v, ok := r.payload["total_cents"].(float64); ok {
			total = int64(v)
		}
		mustExec(ctx, conn,
			`INSERT INTO order_status_view (order_id, status, total_cents, last_seq)
			 VALUES ($1,'PLACED',$2,$3)
			 ON CONFLICT (order_id) DO UPDATE SET status='PLACED', total_cents=$2, last_seq=$3`,
			r.aggID, total, r.seq)
	case "OrderPaid":
		mustExec(ctx, conn, `UPDATE order_status_view SET status='PAID', last_seq=$2 WHERE order_id=$1`, r.aggID, r.seq)
	case "OrderShipped":
		mustExec(ctx, conn, `UPDATE order_status_view SET status='SHIPPED', last_seq=$2 WHERE order_id=$1`, r.aggID, r.seq)

		// === SEEDED BUG (Beat 3 break-it) ===
		// OrderCancelled is NOT handled here, so a cancelled order is stuck showing its
		// previous status (e.g. PAID) in the read model, even though `state` (the fold)
		// correctly reports CANCELLED. THIS is the projection bug.
		//
		// TODO (the one insight): add the missing case, then run `go run . replay`.
		// Every read model is recomputed from true history — no data-migration guesswork.
		//
		// case "OrderCancelled":
		// 	mustExec(ctx, conn, `UPDATE order_status_view SET status='CANCELLED', last_seq=$2 WHERE order_id=$1`, r.aggID, r.seq)
	}
}

func dumpView(ctx context.Context, conn *pgx.Conn) {
	rows, err := conn.Query(ctx, `SELECT order_id, status, total_cents, last_seq FROM order_status_view ORDER BY order_id`)
	if err != nil {
		log.Fatalf("view: %v", err)
	}
	defer rows.Close()
	fmt.Println("order_status_view (the projection / read model):")
	for rows.Next() {
		var id, st string
		var total int64
		var ls int
		_ = rows.Scan(&id, &st, &total, &ls)
		fmt.Printf("  %-12s status=%-9s total_cents=%-6d last_seq=%d\n", id, st, total, ls)
	}
}

func dumpLog(ctx context.Context, conn *pgx.Conn) {
	rows, err := conn.Query(ctx, `SELECT global_seq, aggregate_id, seq, event_type, payload FROM events ORDER BY global_seq`)
	if err != nil {
		log.Fatalf("log: %v", err)
	}
	defer rows.Close()
	fmt.Println("event store (source of truth):")
	for rows.Next() {
		var gs int64
		var id, et string
		var seq int
		var pb []byte
		_ = rows.Scan(&gs, &id, &seq, &et, &pb)
		fmt.Printf("  g%-3d %-12s v%-2d %-15s %s\n", gs, id, seq, et, string(pb))
	}
}

// helpers
func must(n int, args []string) {
	if len(args) < n {
		log.Fatalf("expected %d arg(s), got %d", n, len(args))
	}
}
func mustExec(ctx context.Context, conn *pgx.Conn, sql string, args ...any) {
	if _, err := conn.Exec(ctx, sql, args...); err != nil {
		log.Fatalf("exec %q: %v", sql, err)
	}
}
func atoi(s string) int { n, _ := strconv.Atoi(s); return n }
