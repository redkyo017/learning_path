// Day 9 — steady load at service A's /get while we degrade dependency B.
// Uses constant-arrival-rate to hold a fixed λ (req/s) regardless of latency, so
// you can see A's latency/errors change purely from B's behavior + the protections.
//
// Run against the gateway (A) on :8082:
//   k6 run days/day09-circuit-breakers/lab/k6/load.js
import http from 'k6/http';
import { check } from 'k6';
import { Counter } from 'k6/metrics';

const live = new Counter('served_live');
const degraded = new Counter('served_fallback');
const errors = new Counter('served_error');

export const options = {
  scenarios: {
    steady: {
      executor: 'constant-arrival-rate',
      rate: 200,             // λ = 200 req/s (tune to your machine)
      timeUnit: '1s',
      duration: '60s',
      preAllocatedVUs: 300,  // enough VUs to sustain λ even when A is slow
      maxVUs: 600,
    },
  },
};

const BASE = __ENV.BASE || 'http://localhost:8082';

export default function () {
  const res = http.get(`${BASE}/get`);
  const src = res.headers['X-Source'];
  if (res.status === 200 && src === 'live') live.add(1);
  else if (res.status === 200) degraded.add(1);   // fallback-cache
  else errors.add(1);
  check(res, { 'not 5xx': (r) => r.status < 500 });
}
