// Inventory gRPC server. Run:  go run ./server
//
// Prereq: `buf generate` has produced gen/order/v1/*.go (see lab/README.md).
package main

import (
	"context"
	"log"
	"net"

	orderv1 "grpclab/gen/order/v1"

	"google.golang.org/grpc"
)

// in-memory stock, keyed by SKU.
var stock = map[string]int32{
	"SKU1": 10,
	"SKU2": 0,
}

type inventoryServer struct {
	orderv1.UnimplementedInventoryServer // forward-compat: unknown future RPCs return Unimplemented
}

func (s *inventoryServer) CheckStock(ctx context.Context, req *orderv1.CheckStockRequest) (*orderv1.CheckStockResponse, error) {
	onHand := stock[req.GetSku()]

	// === TODO (the one insight — Beat 3, step B) ===
	// After you add `string warehouse = 4;` to the proto and regenerate, make
	// stock per-warehouse (map[warehouse]map[sku]int32) and select it from
	// req.GetWarehouse(). Old callers send "" -> treat "" as the default
	// warehouse so they keep working. This is what "additive + safe default" means.

	log.Printf("CheckStock order=%s sku=%s qty=%d -> on_hand=%d",
		req.GetOrderId(), req.GetSku(), req.GetQuantity(), onHand)

	return &orderv1.CheckStockResponse{
		Available: onHand >= req.GetQuantity(),
		OnHand:    onHand,
	}, nil
}

func main() {
	lis, err := net.Listen("tcp", ":50051")
	if err != nil {
		log.Fatalf("listen: %v", err)
	}
	s := grpc.NewServer()
	orderv1.RegisterInventoryServer(s, &inventoryServer{})
	log.Println("inventory server listening on :50051")
	log.Fatal(s.Serve(lis))
}
