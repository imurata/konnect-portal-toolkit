#!/bin/bash
. ~/work/env/konnect-env.sh
set -x
API_LIST=("IntraAPI" "CorporateAPI" "CustomerAPI")

AUTH_STRATEGY_NAME=apikey


#alias base64='/opt/homebrew/bin/gbase64'
if [ -z "$KONNECT_TOKEN" ]; then
    echo "Failed to set KONNECT_TOKEN"
    exit 1
fi


function create_api_product() {
  API_NAME=$1
  if [ -z "$API_NAME" ]; then
    echo "API_NAME is empty."
    return 1
  fi
  # Get the portal ID for "default-dev-portal"
  PORTAL_ID=$(curl -X GET -s \
      https://us.api.konghq.com/v2/portals \
      -H "Authorization: Bearer $KONNECT_TOKEN" \
      | jq -r '.data[] | select(.name == "default-dev-portal") | .id')

  # Create API Product
  curl -X POST \
      https://us.api.konghq.com/v2/api-products \
      -H "Authorization: Bearer $KONNECT_TOKEN" \
      -H 'Content-Type: application/json' \
      -d '{
      "name": "'"$API_NAME"'",
      "portal_ids": ["'"$PORTAL_ID"'"]
      }'

  # Get the newly created Product ID
  PRODUCT_ID=$(curl -X GET -s \
    https://us.api.konghq.com/v2/api-products \
    -H "Authorization: Bearer $KONNECT_TOKEN" \
     | jq -r '.data[] | select(.name == "'"$API_NAME"'") | .id')

  # Create the API product version
  curl -X POST \
      https://us.api.konghq.com/v2/api-products/${PRODUCT_ID}/product-versions \
      -H "Authorization: Bearer $KONNECT_TOKEN" \
      -H 'Content-Type: application/json' \
      -d '{
      "name": "v1",
      "publish_status": "published"
      }'

  # Create Markdown document for the API
  cat <<EOF > ./md-${API_NAME}.md
## ${API_NAME}
This documentation shows how to use ${API_NAME}.
EOF

  # Create OpenAPI specification file
  cat <<EOF > ./oas-${API_NAME}.yaml
openapi: 3.0.0
info:
  title: ${API_NAME}
  version: "0.1"
paths:
  /get:
    get:
      operationId: /get
      responses:
        "200":
          description: "get: response 200"
  /post:
    post:
      operationId: /post
      responses:
        "200":
          description: "post: response 200"
servers:
  - url: https://httpbin.org
EOF

  # Encode and publish the markdown document
  CONTENT=$(gbase64 -w0 md-${API_NAME}.md)
  curl -X POST \
      https://us.api.konghq.com/v2/api-products/${PRODUCT_ID}/documents \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $KONNECT_TOKEN" \
      -d '{
      "slug": "api-product-document",
      "status": "published",
      "title": "API Product Document for '"$API_NAME"'",
      "content": "'"$CONTENT"'",
      "metadata": {
        "author": "John Doe"
      }
      }'

  # Encode and upload the OpenAPI specification
  CONTENT=$(gbase64 -w0 oas-${API_NAME}.yaml)
  VERSION_ID=$(curl -X GET -s \
      https://us.api.konghq.com/v2/api-products/${PRODUCT_ID}/product-versions \
      -H "Authorization: Bearer $KONNECT_TOKEN" \
      | jq -r '.data[] | select(.name == "v1") | .id')

  curl -X POST \
      https://us.api.konghq.com/v2/api-products/${PRODUCT_ID}/product-versions/${VERSION_ID}/specifications \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $KONNECT_TOKEN" \
      -d '{
      "name": "oas-'"$API_NAME"'.yaml",
      "content": "'"$CONTENT"'"
      }'

  # Get the Auth Strategy ID
  AUTH_STRATEGY_ID=$(curl -X GET -s \
      https://us.api.konghq.com/v2/application-auth-strategies \
      -H "Authorization: Bearer $KONNECT_TOKEN" \
      | jq -r '.data[] | select(.name == "'"$AUTH_STRATEGY_NAME"'") | .id')

  # Publish to Dev Portal
  curl -X PATCH \
      https://us.api.konghq.com/v2/portals/${PORTAL_ID}/product-versions/${VERSION_ID} \
      -H "Authorization: Bearer $KONNECT_TOKEN" \
      -H 'Content-Type: application/json' \
      -d '{
          "publish_status": "published",
          "deprecated": false,
          "application_registration_enabled": true,
          "auto_approve_registration": true,
          "auth_strategy_ids": [
            "'"$AUTH_STRATEGY_ID"'"
           ]
      }'

  echo "API Product ${API_NAME} has been created and published."
}


for CREATE_APINAME in "${API_LIST[@]}"; do
    create_api_product "$CREATE_APINAME"
done

exit 0