// Stage A — spike a SYNCHRONOUS service and watch it fall over.
// Hits the shared echo service's /work?ms=50 endpoint directly: every request
// occupies a slot for 50ms, so a 500-VU spike drives concurrency past capacity
// and p95 explodes / requests start failing.
//
// Run (echo must be up on :8080, see lab/README.md):
//   k6 run days/day07-loadleveling/lab/k6/spike-sync.js
import http from 'k6/http';
import { check } from 'k6';

export const options = {
  stages: [
    { duration: '10s', target: 50 },   // warm up
    { duration: '20s', target: 50 },   // steady baseline
    { duration: '10s', target: 500 },  // 10x SPIKE
    { duration: '30s', target: 500 },  // hold the spike — watch it fall over
    { duration: '10s', target: 0 },
  ],
  // No thresholds that abort: we WANT to see the failure. Just record it.
};

const BASE = __ENV.BASE || 'http://localhost:8080';

export default function () {
  const res = http.get(`${BASE}/work?ms=50`);
  check(res, { 'status 200': (r) => r.status === 200 });
}
