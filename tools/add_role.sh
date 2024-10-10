#!/bin/bash
. ~/work/env/konnect-env.sh
set -x

PORTAL_ID=$(curl -X GET -s \
    https://us.api.konghq.com/v2/portals \
    -H "Authorization: Bearer $KONNECT_TOKEN" \
    | jq -r '.data[] | select(.name == "default-dev-portal") | .id')


function assign_role()
{
    TEAM_NAME=$1
    API_NAME=$2
    ROLE_NAME=$3

    TEAM_ID=$(curl -s -X GET \
        https://us.api.konghq.com/v2/portals/${PORTAL_ID}/teams \
        -H "Authorization: Bearer $KONNECT_TOKEN" \
        | jq -r --arg team_name "$TEAM_NAME" '.data[] | select(.name == $team_name) | .id')

    PRODUCT_ID=$(curl -X GET -s \
      https://us.api.konghq.com/v2/api-products \
      -H "Authorization: Bearer $KONNECT_TOKEN" \
       | jq -r '.data[] | select(.name == "'"$API_NAME"'") | .id')

    # entity_id: "*" or API Product ID
    # "entity_type_name": Fix as "Services"
    curl -X POST \
      https://us.api.konghq.com/v2/portals/${PORTAL_ID}/teams/${TEAM_ID}/assigned-roles \
      -H "Authorization: Bearer $KONNECT_TOKEN" \
      -H 'Content-Type: application/json' \
      -d '{
       "role_name": "'"$ROLE_NAME"'",
       "entity_type_name": "Services",
       "entity_region":"us",
       "entity_id": "'"$PRODUCT_ID"'"
       }'
}

assign_role "All User" "IntraAPI" "API Viewer"

assign_role "Proper Developer" "IntraAPI" "API Viewer"
assign_role "Proper Developer" "CorporateAPI" "API Consumer"
assign_role "Proper Developer" "CustomerAPI" "API Consumer"

assign_role "All Developer" "IntraAPI" "API Viewer"
assign_role "All Developer" "CorporateAPI" "API Viewer"