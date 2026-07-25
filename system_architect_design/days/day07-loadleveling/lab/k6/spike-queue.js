// Stage B/C — spike the QUEUE-BUFFERED service.
// Hits POST /enqueue on the `queue` service (:8090). The handler just pushes a
// job and returns 202, so ingress latency stays FLAT under the same 10x spike;
// the burst shows up as queue DEPTH, not as ingress p95.
//
// Stage C (break-it): with QUEUE_MAX set, an over-capacity spike makes /enqueue
// return 429 once the bound is hit — graceful load shedding. This script counts
// 202 vs 429 so you can see the shed rate.
//
// Run (queue service up on :8090, see lab/README.md):
//   k6 run days/day07-loadleveling/lab/k6/spike-queue.js
import http from 'k6/http';
import { check } from 'k6';
import { Counter } from 'k6/metrics';

const accepted = new Counter('accepted_202');
const shed = new Counter('shed_429');

export const options = {
  stages: [
    { duration: '10s', target: 50 },
    { duration: '20s', target: 50 },
    { duration: '10s', target: 500 },  // same 10x spike as Stage A
    { duration: '30s', target: 500 },
    { duration: '10s', target: 0 },
  ],
};

const BASE = __ENV.BASE || 'http://localhost:8090';

export default function () {
  const res = http.post(`${BASE}/enqueue`, null);
  if (res.status === 202) accepted.add(1);
  if (res.status === 429) shed.add(1);
  check(res, { 'accepted or shed (not 5xx)': (r) => r.status === 202 || r.status === 429 });
}
