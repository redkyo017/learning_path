package main

import (
	"context"
	"fmt"
)

// runStatus prints a quick snapshot: how many orders exist, how many outbox rows
// are still unsent, and how many events the consumer has processed. Use it before
// and after the break-it steps to see the outbox drain (or not).
func runStatus(ctx context.Context) {
	pool := mustPool(ctx)
	defer pool.Close()

	var orders, unsent, sent, processed int
	_ = pool.QueryRow(ctx, `SELECT count(*) FROM orders`).Scan(&orders)
	_ = pool.QueryRow(ctx, `SELECT count(*) FROM outbox WHERE sent_at IS NULL`).Scan(&unsent)
	_ = pool.QueryRow(ctx, `SELECT count(*) FROM outbox WHERE sent_at IS NOT NULL`).Scan(&sent)
	_ = pool.QueryRow(ctx, `SELECT count(*) FROM processed_events`).Scan(&processed)

	fmt.Printf("orders=%d  outbox_unsent=%d  outbox_sent=%d  processed_events=%d\n",
		orders, unsent, sent, processed)
	fmt.Println("inventory:")
	rows, err := pool.Query(ctx, `SELECT product, stock FROM inventory ORDER BY product`)
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var p string
			var s int
			_ = rows.Scan(&p, &s)
			fmt.Printf("  %-8s %d\n", p, s)
		}
	}
}
