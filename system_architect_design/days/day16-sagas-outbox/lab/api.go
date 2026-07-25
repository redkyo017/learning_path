package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
)

type placeOrderReq struct {
	Product string `json:"product"`
	Qty     int    `json:"qty"`
}

// runAPI serves POST /placeOrder. The order row AND the outbox row are written
// in ONE Postgres transaction — that is the whole point: the event becomes
// durable atomically with the business change. Publishing happens later, in the
// relay, out of band.
func runAPI(ctx context.Context) {
	pool := mustPool(ctx)
	defer pool.Close()

	http.HandleFunc("/placeOrder", func(w http.ResponseWriter, r *http.Request) {
		var req placeOrderReq
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Product == "" || req.Qty <= 0 {
			http.Error(w, "want JSON {product, qty>0}", http.StatusBadRequest)
			return
		}

		tx, err := pool.Begin(ctx)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		defer tx.Rollback(ctx) // no-op after a successful commit

		var orderID int64
		if err := tx.QueryRow(ctx,
			`INSERT INTO orders (product, qty) VALUES ($1, $2) RETURNING id`,
			req.Product, req.Qty).Scan(&orderID); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		eventID := uuidv4()
		payload, _ := json.Marshal(map[string]any{
			"type":     "OrderPlaced",
			"event_id": eventID,
			"order_id": orderID,
			"product":  req.Product,
			"qty":      req.Qty,
		})
		if _, err := tx.Exec(ctx,
			`INSERT INTO outbox (aggregate_id, event_type, event_id, payload)
			 VALUES ($1, 'OrderPlaced', $2, $3)`,
			orderID, eventID, payload); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		if err := tx.Commit(ctx); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		w.WriteHeader(http.StatusCreated)
		fmt.Fprintf(w, `{"order_id":%d,"event_id":%q}`+"\n", orderID, eventID)
	})

	log.Println("api listening on :8090  (POST /placeOrder)")
	log.Fatal(http.ListenAndServe(":8090", nil))
}
