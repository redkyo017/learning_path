// Day 6 — the stampede. 200 virtual users hammer ONE hot key for a short burst.
// Run this IMMEDIATELY after busting the key (GET /bust?code=hot), so all VUs
// arrive during the ~50ms it takes the first miss to refill the cache.
//
//   curl -s "$BASE/reset"
//   curl -s "$BASE/bust?code=hot"
//   k6 run --env BASE=http://localhost:8090 stampede.js
//   curl -s "$BASE/stats" | jq      # look at dbQueries
//
// Without singleflight: dbQueries jumps by ~ (concurrent misses)  -> the herd.
// With SINGLEFLIGHT=on:  dbQueries increases by ~1               -> coalesced.
import http from 'k6/http';
import { check } from 'k6';

export const options = {
  vus: 200,
  duration: '2s',
};

const BASE = __ENV.BASE || 'http://localhost:8090';

export default function () {
  const res = http.get(`${BASE}/lookup?code=hot`);
  check(res, { 'status 200': (r) => r.status === 200 });
}
