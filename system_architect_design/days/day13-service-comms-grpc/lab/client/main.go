// Orders gRPC client -> Inventory. Run (server must be up):
//
//	go run ./client -sku SKU1 -qty 3
//
// Note the per-call deadline: a gRPC call with no context deadline hangs forever
// on a stuck peer (the Day 9 cascade). Always set one.
package main

import (
	"context"
	"flag"
	"log"
	"time"

	orderv1 "grpclab/gen/order/v1"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

func main() {
	addr := flag.String("addr", "localhost:50051", "inventory server address")
	orderID := flag.String("order", "o1", "order id")
	sku := flag.String("sku", "SKU1", "sku")
	qty := flag.Int("qty", 3, "quantity")
	flag.Parse()

	conn, err := grpc.NewClient(*addr, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		log.Fatalf("dial: %v", err)
	}
	defer conn.Close()
	client := orderv1.NewInventoryClient(conn)

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	resp, err := client.CheckStock(ctx, &orderv1.CheckStockRequest{
		OrderId:  *orderID,
		Sku:      *sku,
		Quantity: int32(*qty),
	})
	if err != nil {
		log.Fatalf("CheckStock: %v", err)
	}
	log.Printf("available=%v on_hand=%d (requested qty=%d)", resp.GetAvailable(), resp.GetOnHand(), *qty)
}
