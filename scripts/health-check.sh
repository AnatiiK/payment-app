#!/bin/bash
# health-check.sh
# Verifies payment app endpoints are responding correctly
# Usage: ./health-check.sh [production|staging]

set -e

ENV=${1:-production}

# Colours
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ "$ENV" == "staging" ]; then
  BASE_URL="http://payments.anathi.xyz:8080"
  echo "Checking STAGING environment"
else
  BASE_URL="https://payments.anathi.xyz"
  echo "Checking PRODUCTION environment"
fi

echo "================================================"
echo " Payment App — Health Check"
echo " Environment: $ENV"
echo " URL: $BASE_URL"
echo " $(date)"
echo "================================================"
echo ""

# ── Helper function ────────────────────────────────
check_endpoint() {
  local NAME=$1
  local URL=$2
  local EXPECTED_CODE=$3

  RESPONSE=$(curl -s -o /tmp/response_body -w "%{http_code}|%{time_total}" \
    --max-time 10 \
    --connect-timeout 5 \
    "$URL" 2>/dev/null || echo "000|0")

  HTTP_CODE=$(echo $RESPONSE | cut -d'|' -f1)
  LATENCY=$(echo $RESPONSE | cut -d'|' -f2)
  BODY=$(cat /tmp/response_body 2>/dev/null || echo "")

  if [ "$HTTP_CODE" -eq "$EXPECTED_CODE" ] 2>/dev/null; then
    echo -e "  ${GREEN}✅ $NAME${NC}"
    echo "     Status: $HTTP_CODE | Latency: ${LATENCY}s"
    echo "     Response: ${BODY:0:80}"
  else
    echo -e "  ${RED}❌ $NAME${NC}"
    echo "     Expected: $EXPECTED_CODE | Got: $HTTP_CODE | Latency: ${LATENCY}s"
    echo "     Response: ${BODY:0:80}"
  fi
  echo ""
}

# ── Run checks ─────────────────────────────────────
check_endpoint "Health endpoint"   "$BASE_URL/health"   200
check_endpoint "Payments endpoint" "$BASE_URL/payments" 200

# ── Summary ────────────────────────────────────────
echo "================================================"
echo " Check complete: $(date)"
echo "================================================"
