// shard demonstrates the rebalancing cost of two client-side sharding schemes:
//
//	modulo:            node = hash(key) % N          -> ~2/3 of keys move on 2->3
//	consistent hash:   first node clockwise on a ring -> ~1/3 of keys move on 2->3
//
// It also measures load balance across shards and shows the hot-key failure mode
// (a single key can't be spread by ANY hashing scheme).
//
// Usage (run `go mod tidy` first):
//
//	go run .                 # pure measurement, no database needed
//	go run . -keys 1000000   # more keys = tighter fractions
//	go run . -vnodes 200     # virtual nodes per physical node (balance knob)
//	go run . -pg             # ALSO route inserts into the 3 real Postgres shards
//	                         # (bring them up first — see ../README.md)
package main

import (
	"database/sql"
	"flag"
	"fmt"
	"hash/fnv"
	"log"
	"sort"

	_ "github.com/lib/pq"
)

// ---- hashing --------------------------------------------------------------

func hash32(s string) uint32 {
	h := fnv.New32a()
	_, _ = h.Write([]byte(s))
	return h.Sum32()
}

// ---- consistent-hash ring -------------------------------------------------

type Ring struct {
	vnodes int
	points []uint32          // sorted ring positions
	owner  map[uint32]string // position -> physical node
}

func NewRing(vnodes int, nodes ...string) *Ring {
	r := &Ring{vnodes: vnodes, owner: map[uint32]string{}}
	for _, n := range nodes {
		r.Add(n)
	}
	return r
}

// Add places `vnodes` virtual points for a physical node on the ring.
func (r *Ring) Add(node string) {
	for i := 0; i < r.vnodes; i++ {
		p := hash32(fmt.Sprintf("%s#%d", node, i))
		r.points = append(r.points, p)
		r.owner[p] = node
	}
	sort.Slice(r.points, func(i, j int) bool { return r.points[i] < r.points[j] })
}

// Get returns the node that owns key: the first ring point clockwise from it.
func (r *Ring) Get(key string) string {
	h := hash32(key)
	idx := sort.Search(len(r.points), func(i int) bool { return r.points[i] >= h })
	if idx == len(r.points) { // wrapped past the last point
		idx = 0
	}
	return r.owner[r.points[idx]]
}

// TODO (learner): implement Remove(node) — delete that node's vnodes and re-sort.
// Then add a `-remove` path that measures what fraction of keys move when a node
// LEAVES the ring. Predict it first (hint: also ~1/N), then verify. This is the
// insight to implement yourself; nothing above depends on it.
func (r *Ring) Remove(node string) {
	panic("TODO: implement Ring.Remove and measure removal rebalancing")
}

// ---- experiment -----------------------------------------------------------

func main() {
	n := flag.Int("keys", 100000, "number of keys to generate")
	vnodes := flag.Int("vnodes", 150, "virtual nodes per physical node")
	usePG := flag.Bool("pg", false, "also route inserts into the 3 Postgres shards")
	flag.Parse()

	keys := make([]string, *n)
	for i := range keys {
		keys[i] = fmt.Sprintf("code-%d", i) // stand-ins for short_codes
	}

	// --- modulo: 2 nodes then 3 nodes ---
	moduloMoved := 0
	mod3 := map[int]int{}
	for _, k := range keys {
		h := hash32(k)
		before := int(h % 2)
		after := int(h % 3)
		if before != after {
			moduloMoved++
		}
		mod3[after]++
	}

	// --- consistent hash: {A,B} then {A,B,C} ---
	ring2 := NewRing(*vnodes, "A", "B")
	ring3 := NewRing(*vnodes, "A", "B", "C")
	chMoved := 0
	ch3 := map[string]int{}
	for _, k := range keys {
		if ring2.Get(k) != ring3.Get(k) {
			chMoved++
		}
		ch3[ring3.Get(k)]++
	}

	fmt.Printf("=== Rebalancing cost (2 -> 3 nodes, %d keys) ===\n", *n)
	fmt.Printf("modulo (hash %% N)     : %6d keys moved (%.1f%%)  <- expect ~66.7%%\n",
		moduloMoved, pct(moduloMoved, *n))
	fmt.Printf("consistent hash (ring): %6d keys moved (%.1f%%)  <- expect ~33.3%%\n",
		chMoved, pct(chMoved, *n))
	fmt.Printf("=> consistent hashing moved ~%.1fx fewer keys\n\n",
		float64(moduloMoved)/float64(max1(chMoved)))

	fmt.Printf("=== Load balance at 3 nodes ===\n")
	fmt.Printf("modulo          : %v\n", mod3)
	fmt.Printf("consistent hash : %v  (vnodes=%d)\n", ch3, *vnodes)
	fmt.Printf("consistent-hash imbalance (max/min): %.2f  (closer to 1.0 with more vnodes)\n\n",
		imbalance(ch3))

	// --- BREAK IT: the hot key ---
	fmt.Printf("=== Hot key (celebrity) — 100%% of traffic on ONE key ===\n")
	hot := "viral-code"
	fmt.Printf("consistent hash routes every request for %q to node %q.\n", hot, ring3.Get(hot))
	fmt.Printf("No hashing scheme can split a single key across shards — that shard eats 100%%.\n")
	fmt.Printf("Mitigations live ABOVE the partitioner: cache it (Day 6), key-split, or replica reads (Day 4).\n\n")

	if *usePG {
		routeIntoPostgres(keys, ring3)
	}
}

func pct(a, b int) float64 { return 100 * float64(a) / float64(b) }
func max1(a int) int {
	if a == 0 {
		return 1
	}
	return a
}
func imbalance(m map[string]int) float64 {
	mn, mx := 1<<62, 0
	for _, v := range m {
		if v < mn {
			mn = v
		}
		if v > mx {
			mx = v
		}
	}
	if mn == 0 {
		return 0
	}
	return float64(mx) / float64(mn)
}

// ---- optional: route into real Postgres shards ----------------------------

func routeIntoPostgres(keys []string, ring *Ring) {
	dsn := map[string]string{
		"A": "host=localhost port=5441 user=postgres password=pass dbname=app sslmode=disable",
		"B": "host=localhost port=5442 user=postgres password=pass dbname=app sslmode=disable",
		"C": "host=localhost port=5443 user=postgres password=pass dbname=app sslmode=disable",
	}
	db := map[string]*sql.DB{}
	for node, d := range dsn {
		conn, err := sql.Open("postgres", d)
		if err != nil {
			log.Fatalf("open %s: %v", node, err)
		}
		if err := conn.Ping(); err != nil {
			log.Fatalf("ping %s (is shard up? see ../README.md): %v", node, err)
		}
		if _, err := conn.Exec(`CREATE TABLE IF NOT EXISTS links(
			short_code TEXT PRIMARY KEY, long_url TEXT NOT NULL)`); err != nil {
			log.Fatalf("create on %s: %v", node, err)
		}
		if _, err := conn.Exec(`TRUNCATE links`); err != nil {
			log.Fatalf("truncate on %s: %v", node, err)
		}
		db[node] = conn
	}
	fmt.Printf("=== Routing %d keys into 3 real Postgres shards (consistent hash) ===\n", len(keys))
	// Sample to keep the lab fast; bump if you want the full set.
	sample := keys
	if len(sample) > 20000 {
		sample = sample[:20000]
	}
	for _, k := range sample {
		node := ring.Get(k)
		if _, err := db[node].Exec(
			`INSERT INTO links(short_code,long_url) VALUES ($1,$2) ON CONFLICT DO NOTHING`,
			k, "https://x/"+k); err != nil {
			log.Fatalf("insert %s -> %s: %v", k, node, err)
		}
	}
	for _, node := range []string{"A", "B", "C"} {
		var c int
		_ = db[node].QueryRow(`SELECT count(*) FROM links`).Scan(&c)
		fmt.Printf("shard %s (%s): %d rows\n", node, dsn[node], c)
	}
	fmt.Println("Row counts should be roughly even — that's your balance, verified on real shards.")
}
