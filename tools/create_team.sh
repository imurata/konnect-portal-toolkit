#!/bin/bash
. ~/work/env/konnect-env.sh
set -x

if [ -z "$KONNECT_TOKEN" ]; then
    echo "Failed to set KONNECT_TOKEN"
    exit 1
fi 

PORTAL_ID=$(curl -X GET -s \
    https://us.api.konghq.com/v2/portals \
    -H "Authorization: Bearer $KONNECT_TOKEN" \
    | jq -r '.data[] | select(.name == "default-dev-portal") | .id')

function create_team(){
  TEAM=$1
  DESCRIPTION=$2
  curl -X POST \
    https://us.api.konghq.com/v2/portals/${PORTAL_ID}/teams \
    -H "Authorization: Bearer $KONNECT_TOKEN" \
    -H 'Content-Type: application/json' \
    -d '{
     "name": "'"$TEAM"'",
     "description": "'"$DESCRIPTION"'"
     }'
}

create_team "All User" "Default team"
create_team "All Developer" "Default Developer team"
create_team "Proper Developer" "Proper Developer team"