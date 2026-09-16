#!/usr/bin/env bash
# Phase 3 smoke test — end-to-end validation of CP → GW → IS integration
# Prerequisites: docker compose up (from labs/phase3/day43/)
# Usage: bash smoke_test.sh
set -euo pipefail

CP="http://localhost:8082"
IS="http://localhost:8080"
GW="http://localhost:9090"

echo "=== Phase 3 Smoke Test ==="

# Step 1: Create + publish API in CP
echo "[1] Create API..."
API=$(curl -sf -X POST "$CP/apis" \
  -H 'Content-Type: application/json' \
  -d '{"name":"SmokeAPI","context":"/smoke/v1","version":"1.0","backendUrl":"http://backend:8000","allowedTiers":["Gold"]}')
API_ID=$(echo "$API" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
[ -z "$API_ID" ] && { echo "FAIL: could not create API"; exit 1; }
echo "  Created: $API_ID"

echo "[2] Publish API..."
curl -sf -X POST "$CP/apis/$API_ID/lifecycle" \
  -H 'Content-Type: application/json' -d '{"action":"Publish"}' > /dev/null
echo "  Published."

# Step 2: Create application + subscription
echo "[3] Create application..."
APP=$(curl -sf -X POST "$CP/applications" \
  -H 'Content-Type: application/json' \
  -d '{"name":"SmokeApp","owner":"tester"}')
APP_ID=$(echo "$APP"    | grep -o '"id":"[^"]*"'          | head -1 | cut -d'"' -f4)
KEY=$(echo "$APP"       | grep -o '"consumerKey":"[^"]*"'  | cut -d'"' -f4)
echo "  App: $APP_ID  Key: $KEY"

echo "[4] Subscribe app to API (Gold tier)..."
curl -sf -X POST "$CP/subscriptions" \
  -H 'Content-Type: application/json' \
  -d "{\"appId\":\"$APP_ID\",\"apiId\":\"$API_ID\",\"tier\":\"Gold\"}" > /dev/null
echo "  Subscribed."

echo "[5] Register API context for validate endpoint..."
curl -sf -X POST "$CP/admin/apis" \
  -H 'Content-Type: application/json' \
  -d "{\"apiId\":\"$API_ID\",\"apiContext\":\"/smoke/v1\"}" > /dev/null || true
echo "  Done."

# Step 3: Get JWT from IS
echo "[6] Obtain JWT from IS..."
TOKEN_RESP=$(curl -sf -X POST "$IS/oauth2/token" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d "grant_type=client_credentials&client_id=${KEY}&client_secret=unused&scope=default")
ACCESS_TOKEN=$(echo "$TOKEN_RESP" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
[ -z "$ACCESS_TOKEN" ] && { echo "FAIL: IS did not return access_token"; exit 1; }
echo "  Token: ${ACCESS_TOKEN:0:30}..."

# Step 4: Call GW
echo "[7] Call API through GW..."
HTTP_CODE=$(curl -sf -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  "$GW/smoke/v1/hello" || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
  echo "  PASS — GW returned 200"
else
  echo "  FAIL — GW returned $HTTP_CODE"
  exit 1
fi

echo ""
echo "=== ALL STEPS PASSED ==="
