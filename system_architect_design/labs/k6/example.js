// Template k6 load script. Copy per day and adjust.
// Run:  k6 run example.js
// Docs: https://grafana.com/docs/k6/latest/
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  // Ramping spike profile — reuse this shape for the Day 7 load-leveling lab.
  stages: [
    { duration: '10s', target: 50 },   // ramp to 50 virtual users
    { duration: '30s', target: 50 },   // hold
    { duration: '10s', target: 500 },  // spike
    { duration: '20s', target: 500 },  // hold the spike
    { duration: '10s', target: 0 },    // ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<200'],  // p95 under 200ms (tune per lab)
    http_req_failed: ['rate<0.01'],    // <1% errors
  },
};

const BASE = __ENV.BASE || 'http://localhost:8080';

export default function () {
  const res = http.get(`${BASE}/work?ms=50`);
  check(res, { 'status 200': (r) => r.status === 200 });
  sleep(0.1);
}
