#!/bin/bash
# Render Deployment Script
# Usage: ./deploy-render.sh [service-id]

RENDER_API_KEY="${RENDER_API_KEY:?RENDER_API_KEY must be set in the environment (no hardcoded default)}"
SERVICE_ID="${1:-}"

if [ -z "$SERVICE_ID" ]; then
    echo "Usage: $0 <service-id>"
    echo "Or set SERVICE_ID environment variable"
    echo ""
    echo "To find your service ID:"
    echo "  1. Go to https://dashboard.render.com"
    echo "  2. Select your service"
    echo "  3. Copy the service ID from the URL or settings"
    exit 1
fi

echo "Deploying to Render..."
echo "Service ID: $SERVICE_ID"

# Trigger deployment
RESPONSE=$(curl -s -X POST \
    -H "Authorization: Bearer $RENDER_API_KEY" \
    -H "Content-Type: application/json" \
    -d '{"clearCache": "start"}' \
    "https://api.render.com/v1/services/$SERVICE_ID/deploys" 2>&1)

if echo "$RESPONSE" | grep -q "id"; then
    echo "✅ Deployment triggered successfully!"
    echo "$RESPONSE" | jq -r '.id' 2>/dev/null && echo "Deploy ID: $(echo $RESPONSE | jq -r '.id')"
else
    echo "❌ Deployment failed"
    echo "Response: $RESPONSE"
fi
