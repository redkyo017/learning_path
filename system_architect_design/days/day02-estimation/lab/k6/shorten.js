// Day 2 load script — validate your capacity estimate against the real service.
//
// Two modes (pick with MODE env):
//
//   MODE=rate  (default) — drive a CONSTANT target write RPS for 60s and see if the
//              single instance holds your latency budget. Set your ESTIMATED peak
//              write QPS here (Day 2 said ~6,000/s; a laptop won't reach that — that's
//              the lesson: one instance has a ceiling far below the fleet estimate).
//                k6 run --env MODE=rate --env TARGET_RPS=2000 shorten.js
//
//   MODE=spike — ramp virtual users up until p95 blows past the budget, to FIND the
//              single-instance ceiling. Watch where http_req_failed climbs.
//                k6 run --env MODE=spike shorten.js
//
// BASE defaults to the local shortener. LAT_BUDGET_MS is your redirect/create p95 SLO.
import http from 'k6/http';
import { check } from 'k6';

const BASE = __ENV.BASE || 'http://localhost:8080';
const MODE = __ENV.MODE || 'rate';
const TARGET_RPS = parseInt(__ENV.TARGET_RPS || '2000', 10);
const LAT_BUDGET_MS = parseInt(__ENV.LAT_BUDGET_MS || '100', 10);

const scenarios = {
  rate: {
    executor: 'constant-arrival-rate',
    rate: TARGET_RPS,        // iterations (requests) per second we TRY to send
    timeUnit: '1s',
    duration: '60s',
    preAllocatedVUs: 200,    // raise if k6 warns it can't reach the target rate
    maxVUs: 2000,
  },
  spike: {
    executor: 'ramping-vus',
    startVUs: 10,
    stages: [
      { duration: '20s', target: 50 },
      { duration: '20s', target: 200 },
      { duration: '20s', target: 500 },
      { duration: '20s', target: 1000 }, // keep climbing until p95 breaks the budget
      { duration: '10s', target: 0 },
    ],
  },
};

export const options = {
  scenarios: { [MODE]: scenarios[MODE] },
  thresholds: {
    // These are ASSERTIONS about your estimate. When they go red, you've found the
    // ceiling — that's the point of the lab, not a failure to fix.
    http_req_duration: [`p(95)<${LAT_BUDGET_MS}`],
    http_req_failed: ['rate<0.01'],
  },
};

export default function () {
  const payload = JSON.stringify({ url: `https://example.com/${__VU}/${__ITER}` });
  const res = http.post(`${BASE}/shorten`, payload, {
    headers: { 'Content-Type': 'application/json' },
  });
  check(res, { 'created 201': (r) => r.status === 201 });
}
