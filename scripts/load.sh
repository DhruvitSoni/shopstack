#!/usr/bin/env bash
# Simple traffic generator: browse products and place orders so Grafana has something to show.
set -euo pipefail
URL="${1:-http://localhost:8080}"
echo "Sending traffic to $URL (Ctrl+C to stop)"
while true; do
  curl -s -o /dev/null "$URL/api/products"
  curl -s -o /dev/null "$URL/api/orders"
  curl -s -o /dev/null -X POST -H 'content-type: application/json' \
    -d "{\"productId\": $((RANDOM % 3 + 1)), \"qty\": 1}" "$URL/api/orders"
  curl -s -o /dev/null "$URL/api/products/999"   # some 404s for the status panel
  sleep 0.2
done
