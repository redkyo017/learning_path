// Package compat proves schema compatibility at the WIRE level, offline, without
// running two builds. It unmarshals bytes captured under the BASELINE schema into
// whatever the CURRENT generated struct is.
//
//	go test ./compat/
//
// Baseline / additive schema  -> PASS  (quantity is still field 3)
// After renumbering quantity  -> FAIL  (old bytes carry field 3; struct wants 7)
package compat

import (
	"testing"

	orderv1 "grpclab/gen/order/v1"

	"google.golang.org/protobuf/proto"
)

// Wire bytes of CheckStockRequest{order_id:"o1", sku:"SKU1", quantity:5}
// serialized under the BASELINE schema (order_id=1, sku=2, quantity=3).
// tag = (field_number << 3) | wire_type ; wire_type 2 = length-delimited, 0 = varint.
var baselineWire = []byte{
	0x0A, 0x02, 'o', '1', // field 1 (1<<3|2), len 2, "o1"
	0x12, 0x04, 'S', 'K', 'U', '1', // field 2 (2<<3|2), len 4, "SKU1"
	0x18, 0x05, // field 3 (3<<3|0), varint 5
}

func TestOldWireStillReadsQuantity(t *testing.T) {
	var req orderv1.CheckStockRequest
	if err := proto.Unmarshal(baselineWire, &req); err != nil {
		t.Fatalf("unmarshal failed: %v", err)
	}
	if req.GetOrderId() != "o1" || req.GetSku() != "SKU1" {
		t.Fatalf("string fields garbled: order=%q sku=%q", req.GetOrderId(), req.GetSku())
	}
	// The load-bearing assertion. Adding a field keeps this green (proof additive
	// is safe). Renumbering `quantity` turns it red with quantity=0 (proof the
	// field NUMBER, not the name, is the wire contract) -- a silent data loss.
	if got := req.GetQuantity(); got != 5 {
		t.Fatalf("quantity = %d, want 5 -- a field number changed; every old peer now silently loses this value", got)
	}
}
