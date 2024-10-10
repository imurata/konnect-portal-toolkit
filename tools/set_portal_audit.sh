#!/bin/bash
. ~/work/env/konnect-env.sh
set -x

PORTAL_ID="a0c7d46c-87a5-4ad9-beb4-9445xxxx"
REGION=us
SIEM_ENDPOINT=https://xxx.free.beeceptor.com
AUTORIZATION="Bearer example-token"

if [ -z "$KONNECT_TOKEN" ]; then
    echo "Failed to set KONNECT_TOKEN"
    exit 1
fi 

## Register SIEM Endpoint to Konnect for Portal's audit log
curl -X POST https://global.api.konghq.com/v2/audit-log-destinations \
       -H "Content-Type: application/json" \
       -H "Authorization: Bearer $KONNECT_TOKEN" \
       -d '{
       "endpoint": "'"$SIEM_ENDPOINT"'",
       "authorization":"'"$AUTORIZATION"'",
       "log_format":"cef",
       "name":"Webhook Endpoint",
       "skip_ssl_verification": true
       }'

## Get registered SIEM Endpoint ID
DEST_ID=$(curl -s -X GET https://global.api.konghq.com/v2/audit-log-destinations \
       -H "Content-Type: application/json" \
       -H "Authorization: Bearer $KONNECT_TOKEN" | jq -r ".data[0].id")

## Enable Portal's audit log
curl -X PATCH https://${REGION}.api.konghq.com/v2/portals/${PORTAL_ID}/audit-log-webhook \
       -H "Content-Type: application/json" \
       -H "Authorization: Bearer $KONNECT_TOKEN" \
       -d '{
       "audit_log_destination_id": "'"${DEST_ID}"'",
       "enabled": true
       }'

## Confirm the setting
curl -X GET https://${REGION}.api.konghq.com/v2/portals/${PORTAL_ID}/audit-log-webhook/status \
       -H "Content-Type: application/json" \
       -H "Authorization: Bearer $KONNECT_TOKEN"