#!/bin/bash

# Restrictions:
# - API Product allows duplicate Product and Version names, but this script does not support them
#  (duplicates will not result in the intended behaviour)
# - The file name and title of the document must match (not including the file extension).

. ~/work/env/konnect-env.sh

if ! which gbase64 > /dev/null; then
    alias gbase64=base64
fi

if [ -z "$KONNECT_TOKEN" ]; then
    echo "Failed to set KONNECT_TOKEN"
    exit 1
fi 

# Function to check if the file exists and has the correct extension
function check_file() {
    local file="$1"
    local expected_extension="$2"

    # Check if the file exists
    if [ ! -f "$file" ]; then
        echo "Error: File '$file' does not exist."
        return 1
    fi

    # Check if the file has the correct extension
    case "$expected_extension" in
        markdown)
            if [[ "$file" != *.md ]]; then
                echo "Error: File '$file' is not a Markdown file (.md)."
                return 1
            fi
            ;;
        yaml)
            if [[ "$file" != *.yaml && "$file" != *.yml ]]; then
                echo "Error: File '$file' is not a YAML file (.yaml or .yml)."
                return 1
            fi
            ;;
        *)
            echo "Error: Unknown expected extension."
            return 1
            ;;
    esac
    return 0
}

# Function to upload or update a Markdown document
function update_doc() {
    local file="$1"
    local msg="Document '$file' has been successfully uploaded."
    local return_code=0

    # Validate the file
    if ! check_file "$file" "markdown"; then
        return 1
    fi
    
    echo "Updating documentation for file: $file in API Product $PRODUCT_NAME"
    
    # Check if the document is already uploaded
    filename=$(sed "s|.*/||;s|.md$||" <<< "$file" )
    DOC_ID=$(curl -s -X GET \
          https://us.api.konghq.com/v2/api-products/${PRODUCT_ID}/documents \
          -H "Authorization: Bearer $KONNECT_TOKEN" \
          | jq -r --arg filename "${filename}" '.data[] | select(.title == $filename) | .id')

    # Encode the file contents in base64
    CONTENT=$(gbase64 -w0 "$file")
    
    if [ -z "$DOC_ID" ]; then
        # If no document exists, create a new one
        action=create
        curl_response=$(curl -w "\n%{http_code}" -X POST \
            https://us.api.konghq.com/v2/api-products/${PRODUCT_ID}/documents \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $KONNECT_TOKEN" \
            -d '{
            "slug": "api-product-document",
            "status": "published",
            "title": "'"$filename"'",
            "content": "'"$CONTENT"'",
            "metadata": {
                "author": "John Doe"
            }
            }')
    else
        # If the document exists, update it
        action=update
        curl_response=$(curl -w "\n%{http_code}" -X PATCH \
            https://us.api.konghq.com/v2/api-products/${PRODUCT_ID}/documents/$DOC_ID \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $KONNECT_TOKEN" \
            -d '{
            "content": "'"$CONTENT"'"
            }')
    fi
    
    http_code=$(tail -n 1 <<< "$curl_response")
    # Check if the request succeeded
    if [[ "$http_code" -lt 200 || "$http_code" -ge 300 ]]; then
        msg="Failed to $action document. (err: $curl_response)"
        return_code=1
    fi
    echo ""
    echo "---"
    echo "Status Code: $http_code"
    echo $msg
    echo "---"
    return $return_code
}

# Function to upload or update an OpenAPI specification file
function update_spec() {
    local file="$1"
    local version="$2"
    local msg="API Spec '$file' has been successfully uploaded."
    local return_code=0
    
    # Validate the file
    if ! check_file "$file" "yaml"; then
        return 1
    fi
    # Get version ID
    VERSION_ID=$(curl -X GET -s \
        https://us.api.konghq.com/v2/api-products/${PRODUCT_ID}/product-versions \
        -H "Authorization: Bearer $KONNECT_TOKEN" \
        | jq -r '.data[] | select(.name == "'"$version"'") | .id' || true)
    if [ -z "$VERSION_ID" ]; then
        echo "Error: Failed to get Version ID."
        return 1
    fi

    echo "Updating specification for file: $file to version: $version in API Product $PRODUCT_NAME"
    
    # Check if the specification is already uploaded
    filename=${file##*/}
    SPEC_ID=$(curl -s -X GET \
          https://us.api.konghq.com/v2/api-products/${PRODUCT_ID}/product-versions/${VERSION_ID}/specifications \
          -H "Authorization: Bearer $KONNECT_TOKEN" \
          | jq -r --arg filename "$filename" '.data[] | select(.name == $filename) | .id')
    # Encode the file contents in base64
    CONTENT=$(gbase64 -w0 "$file")
    
    if [ -z "$SPEC_ID" ]; then
        # If no specification exists, create a new one
        action=create
        curl_response=$(curl -w "\n%{http_code}" -X POST \
            https://us.api.konghq.com/v2/api-products/${PRODUCT_ID}/product-versions/${VERSION_ID}/specifications \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $KONNECT_TOKEN" \
            -d '{
            "name": "'"$filename"'",
            "content": "'"$CONTENT"'"
            }')
    else
        # If the specification exists, update it
        action=update
        curl_response=$(curl -w "\n%{http_code}" -X PATCH \
            https://us.api.konghq.com/v2/api-products/${PRODUCT_ID}/product-versions/${VERSION_ID}/specifications/${SPEC_ID} \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $KONNECT_TOKEN" \
            -d '{
            "content": "'"$CONTENT"'"
            }')
    fi

    http_code=$(tail -n 1 <<< "$curl_response")
    # Check if the curl command succeeded
    if [[ "$http_code" -lt 200 || "$http_code" -ge 300 ]]; then
        msg="Failed to $action specification. (err: $curl_response)"
        return_code=1
    fi
    echo ""
    echo "---"
    echo "Status Code: $http_code"
    echo $msg
    echo "---"
    return $return_code
}

# Parse command-line arguments
while getopts "d:s:v:p:" opt; do
    case $opt in
        d)
            doc_file=$OPTARG
            ;;
        s)
            spec_file=$OPTARG
            spec_flag=true
            ;;
        v)
            version=$OPTARG
            ;;
        p)
            PRODUCT_NAME=$OPTARG
            # Get product ID
            PRODUCT_ID=$(curl -X GET -s \
                https://us.api.konghq.com/v2/api-products \
                -H "Authorization: Bearer $KONNECT_TOKEN" \
                | jq -r '.data[] | select(.name == "'"$PRODUCT_NAME"'") | .id')
            if [ -z "$PRODUCT_ID" ]; then
                echo "Error: Failed to get API Product ID."
                exit 1
            fi
            ;;
        *)
            echo "Usage: $0 [-d <markdown file>] [-s <yaml file>] -v <version> -p <API Product>"
            exit 1
            ;;
    esac
done

# Check if the product name is specified
if [ -z "$PRODUCT_NAME" ]; then
    echo "Error: API Product name (-p) must be specified."
    exit 1
fi

# Process the -d option if specified
if [ -n "$doc_file" ]; then
    update_doc "$doc_file"
fi

# If -s is specified without -v
if [ "$spec_flag" = true ] && [ -z "$version" ]; then
    echo "Error: -s option requires -v <version> to be specified."
    exit 1
fi

# Process the -s option if specified
if [ "$spec_flag" = true ]; then
    update_spec "$spec_file" "$version"
fi

# If no document or specification file is provided
if [ -z "$doc_file" ] && [ -z "$spec_file" ]; then
    echo "Error: At least one of -d or -s options must be specified."
    exit 1
fi
