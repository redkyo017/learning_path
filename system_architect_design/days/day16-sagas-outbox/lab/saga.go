package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"strconv"
)

// runSaga executes an orchestrated order saga against Postgres:
//
//	reservePayment -> reserveInventory -> confirmOrder
//
// If inventory reservation fails, it COMPENSATES the completed step (refund the
// payment) and cancels the order. Each step is its own local transaction — this
// is what a saga looks like when the steps are genuinely separate services. (In
// this lab they share one DB purely so the demo is self-contained; the point is
// the *shape*: forward steps + reverse compensations, not a single ACID tx.)
//
// Try both:
//
//	go run . saga widget 2   # succeeds  (widget has stock)
//	go run . saga gadget 1   # inventory fails -> payment is refunded (compensation)
func runSaga(ctx context.Context) {
	product := "widget"
	qty := 2
	if len(os.Args) >= 3 {
		product = os.Args[2]
	}
	if len(os.Args) >= 4 {
		if n, err := strconv.Atoi(os.Args[3]); err == nil {
			qty = n
		}
	}

	pool := mustPool(ctx)
	defer pool.Close()

	// Create the order (PLACED).
	var orderID int64
	if err := pool.QueryRow(ctx,
		`INSERT INTO orders (product, qty, status) VALUES ($1,$2,'PLACED') RETURNING id`,
		product, qty).Scan(&orderID); err != nil {
		log.Fatal("create order:", err)
	}
	log.Printf("saga start: order %d  %dx%s", orderID, qty, product)

	// Step 1 — reservePayment (its own tx).
	var paymentID int64
	amount := float64(qty) * 25.0
	if err := pool.QueryRow(ctx,
		`INSERT INTO payments (order_id, amount, status) VALUES ($1,$2,'RESERVED') RETURNING id`,
		orderID, amount).Scan(&paymentID); err != nil {
		log.Fatal("reservePayment:", err)
	}
	log.Printf("  [1] reservePayment OK  payment %d amount %.2f", paymentID, amount)

	// Step 2 — reserveInventory (conditional decrement; 0 rows == out of stock).
	tag, err := pool.Exec(ctx,
		`UPDATE inventory SET stock = stock - $1 WHERE product = $2 AND stock >= $1`,
		qty, product)
	if err != nil {
		log.Fatal("reserveInventory:", err)
	}
	if tag.RowsAffected() == 0 {
		// FAILURE -> compensate in reverse: refund the reserved payment.
		log.Printf("  [2] reserveInventory FAILED (insufficient stock for %s)", product)
		if _, err := pool.Exec(ctx,
			`UPDATE payments SET status='REFUNDED' WHERE id=$1 AND status='RESERVED'`,
			paymentID); err != nil {
			// A real system persists REFUND_PENDING and retries with backoff+jitter.
			log.Fatal("compensation (refund) FAILED — would mark REFUND_PENDING and retry:", err)
		}
		_, _ = pool.Exec(ctx, `UPDATE orders SET status='CANCELLED' WHERE id=$1`, orderID)
		log.Printf("  [C] compensate: refunded payment %d, order %d CANCELLED", paymentID, orderID)
		fmt.Printf("SAGA RESULT: order %d CANCELLED (compensated)\n", orderID)
		return
	}
	log.Printf("  [2] reserveInventory OK  (%s decremented by %d)", product, qty)

	// Step 3 — confirmOrder.
	if _, err := pool.Exec(ctx, `UPDATE orders SET status='CONFIRMED' WHERE id=$1`, orderID); err != nil {
		log.Fatal("confirmOrder:", err)
	}
	log.Printf("  [3] confirmOrder OK")
	fmt.Printf("SAGA RESULT: order %d CONFIRMED\n", orderID)
}
