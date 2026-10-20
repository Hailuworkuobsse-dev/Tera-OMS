#!/usr/bin/env bash
# Tera OMS — End-to-end smoke test
set -uo pipefail
API_URL="${API_URL:-http://localhost:8000}"
DIST_ID="${DIST_ID:-seed-dist-1}"
if [ -t 1 ]; then GREEN='\033[0;32m'; RED='\033[0;31m'; CYAN='\033[0;36m'; GRAY='\033[0;90m'; BOLD='\033[1m'; NC='\033[0m'; else GREEN=''; RED=''; CYAN=''; GRAY=''; BOLD=''; NC=''; fi
P=0; F=0; FC=()
section() { echo -e "\n${BOLD}${CYAN}▸ $1${NC}"; }
check() {
  local n="$1"; shift; echo -n "  $n ... "
  if "$@" > /tmp/te 2>&1; then echo -e "${GREEN}✓${NC}"; P=$((P+1))
  else echo -e "${RED}✗${NC}"; F=$((F+1)); FC+=("$n"); sed 's/^/      /' /tmp/te | head -10; fi
}
require() {
  local n="$1"; shift
  if ! check "$n" "$@"; then
    echo -e "\n${RED}${BOLD}⛔ Aborted — $n failed${NC}"; echo -e "${GRAY}   Hint: pnpm db:migrate && pnpm db:seed${NC}"; summary
  fi
}
summary() { echo -e "\n${BOLD}Passed:${NC} ${GREEN}$P${NC} | ${BOLD}Failed:${NC} ${RED}$F${NC}"; [ $F -gt 0 ] && { echo -e "${RED}Failed:${NC}"; for c in "${FC[@]}"; do echo -e "  - $c"; done; exit 1; }; echo -e "\n${GREEN}${BOLD}✓ ALL CHECKS PASSED${NC}"; exit 0; }

get() { curl -sS --fail-with-body "$API_URL$1" -H 'Content-Type: application/json'; }
post() { curl -sS --fail-with-body -X POST "$API_URL$1" -H 'Content-Type: application/json' -d "${2:-{\}}"; }
post_d() { curl -sS --fail-with-body -X POST "$API_URL$1" -H 'Content-Type: application/json' -H "X-Distributor-Id: $3" -d "${2:-{\}}"; }

t_health() { [ "$(get /health | jq -r '.ok')" = "true" ]; }
t_credit() { [ "$(get /credit/v1/stop-list | jq '.rows | length')" -ge 1 ]; }
t_exposure() { [ "$(get /credit/v1/exposure | jq '.aging_buckets | length')" = "4" ]; }
t_zones() { [ "$(get '/geo/v1/curfew-zones?includeInactive=1' | jq '.zones | length')" -ge 3 ]; }
t_stations() { [ "$(get '/geo/v1/fuel-stations?includeInactive=1' | jq '.stations | length')" -ge 3 ]; }
t_orders() { [ "$(get /orders/v1/pending | jq '.orders | length')" -ge 2 ]; }
t_vehicles() { [ "$(get /routing/v1/vehicles | jq '.vehicles | length')" -ge 1 ]; }
t_routes() { [ "$(get /routing/v1/routes/today | jq '.routes | length')" -ge 1 ]; }
t_board() { [ "$(get /dispatch/v1/board | jq '.docks | length')" -ge 1 ]; }
t_catalog() { [ "$(get /portal/v1/catalog | jq '.items | length')" -ge 1 ]; }
t_me() { [ "$(get /portal/v1/me -H "X-Distributor-Id: $DIST_ID" | jq -r '.distributor_id')" = "$DIST_ID" ]; }
t_dashboard() { [ "$(get /analytics/v1/dashboard | jq '.tiles | length')" -ge 1 ]; }
t_audit() { [ "$(get /audit/v1/log | jq '.entries | length')" -ge 0 ]; }
t_notify() { [ "$(get /notify/v1/templates | jq '.templates | length')" -ge 1 ]; }
t_jobs() { [ "$(get /admin/jobs/v1/schedule | jq '.jobs | length')" = "3" ]; }
t_metrics() { get /metrics | grep -q 'tera_http_requests_total'; }

# Solve flow
t_sync_solve() {
  local ids
  ids=$(get /orders/v1/pending | jq -c '[.orders[].id] | .[0:3]')
  [ "$(echo "$ids" | jq 'length')" -ge 3 ] || { echo "need 3 pending orders"; return 1; }
  local result
  result=$(post /routing/v1/solve "{\"order_ids\":$ids,\"vehicle_id\":\"V-103\"}")
  [ "$(echo "$result" | jq '.optimized.stops | length')" -ge 3 ]
}

# Portal order flow
NEW_ORDER=""
t_place_order() {
  local cat sku
  cat=$(get /portal/v1/catalog); sku=$(echo "$cat" | jq -r '.items[0].sku_id')
  [ -n "$sku" ] || { echo "no SKUs"; return 1; }
  local resp
  resp=$(post_d /portal/v1/orders "{\"lines\":[{\"sku_id\":\"$sku\",\"quantity\":3}]}" "$DIST_ID")
  NEW_ORDER=$(echo "$resp" | jq -r '.order_id')
  [ -n "$NEW_ORDER" ] || { echo "no order_id"; return 1; }
}

# Full flow: pick on V-102, confirm, dispatch
t_pick_and_dispatch() {
  local board route slot status picked
  board=$(get /dispatch/v1/board)
  route=$(echo "$board" | jq -r '[.docks[].slots[] | select(.route.vehicle_id == "V-102")][0].route.id // empty')
  status=$(echo "$board" | jq -r '[.docks[].slots[] | select(.route.vehicle_id == "V-102")][0].status // empty')
  [ -n "$route" ] || { echo "V-102 route not in board"; return 1; }
  if [ "$status" = "ALLOCATED" ]; then
    local pickList stops
    pickList=$(get "/routing/v1/routes/$route/pick-list")
    stops=$(echo "$pickList" | jq -r '.stops[].stop_id')
    for sid in $stops; do post "/routing/v1/routes/$route/stops/$sid/picked" '{}' > /dev/null || return 1; done
    slot=$(echo "$board" | jq -r '[.docks[].slots[] | select(.route.vehicle_id == "V-102")][0].id')
    post "/dispatch/v1/slots/$slot/confirm" '{}' > /dev/null
  fi
  # dispatch
  post "/dispatch/v1/routes/$route/dispatch" '{}' | jq -e '.status == "DISPATCHED"' > /dev/null
}

t_metrics_after() { get /metrics | grep -q 'tera_pending_orders'; }

echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  Tera OMS — End-to-end Smoke Test                             ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
echo -e "${GRAY}  API: $API_URL  |  Distributor: $DIST_ID${NC}"

section "1. Preflight"
require "API is reachable" t_health

section "2. Seed data"
require "Credit stop list" t_credit
require "Exposure with 4 aging buckets" t_exposure
require "Curfew zones (≥3)" t_zones
require "Fuel stations (≥3)" t_stations
require "Pending orders (≥2)" t_orders
require "Vehicles" t_vehicles
require "Today's routes" t_routes
require "Dispatch board" t_board

section "3. Solve"
require "Sync solve returns optimized route" t_sync_solve

section "4. Dispatch flow"
require "Pick all stops + dispatch V-102" t_pick_and_dispatch

section "5. Portal"
require "Catalog has SKUs" t_catalog
require "GET /me returns distributor" t_me
require "Place order via portal" t_place_order

section "6. Analytics + Observability"
require "Exec dashboard returns tiles" t_dashboard
require "Audit log endpoint responds" t_audit
require "Notify templates available" t_notify
require "Job schedule (3 jobs)" t_jobs
require "Prometheus /metrics contains counter" t_metrics
require "Prometheus /metrics contains business gauge" t_metrics_after

summary
