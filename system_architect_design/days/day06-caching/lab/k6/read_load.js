// Day 6 — steady read load with a realistic hot-set skew (~80% of requests hit
// ~20% of keys). Use it to measure hit ratio and p95, with and without the cache.
//
//   k6 run --env BASE=http://localhost:8090 read_load.js
//
// Then read the hit ratio:  curl -s $BASE/stats | jq
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  vus: 50,
  duration: '30s',
  thresholds: {
    http_req_duration: ['p(95)<200'], // tune per your machine
  },
};

const BASE = __ENV.BASE || 'http://localhost:8090';
const HOT = 200;    // the hot 20%
const TOTAL = 1000; // total seeded keys

export default function () {
  // 80% of traffic to the hot set, 20% spread across everything (Pareto-ish).
  const i = Math.random() < 0.8
    ? Math.floor(Math.random() * HOT)
    : Math.floor(Math.random() * TOTAL);
  const res = http.get(`${BASE}/lookup?code=code-${i}`);
  check(res, { 'status 200': (r) => r.status === 200 });
  sleep(0.05);
}
