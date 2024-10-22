#!/bin/bash
. ~/work/env/konnect-env.sh
CONTROL_PLANE=$1
SPECFILE=$2
TAG=my-tag
KONNECT_REGION=us
KONNECT_URL=https://${KONNECT_REGION}.api.konghq.com/

set -e

function usage()
{
    echo "Deploy API Spec to Konnect."
    echo ""
    echo "Usage: $0 <ControlPlane Name> <API Spec>" 
}

if [ -z "$KONNECT_TOKEN" ]; then
    echo "Failed to set KONNECT_TOKEN"
    exit 1
fi 

if ! which inso > /dev/null ; then
    echo "Need inso-cli."
    echo "https://docs.insomnia.rest/inso-cli/install"
    exit 1
fi

if ! which deck > /dev/null ; then
    echo "Need deck."
    echo "https://docs.konghq.com/deck/latest/installation/"
    exit 1
fi

if [ -z "$SPECFILE" ]; then
    usage
    exit 1
fi
if [[ "$SPECFILE" != *.yaml && "$SPECFILE" != *.yml ]]; then
    echo "Error: File '$SPECFILE' is not a YAML file (.yaml or .yml)."
    exit 1
fi


echo "*** 1. Linting ***"
inso lint spec $SPECFILE --verbose

echo "*** 2. Convert API Spec to deck format ***"
deck file openapi2kong -s $SPECFILE -o ./kong.yaml --verbose 9

echo "*** 3. Add global plugins ***"
deck file add-plugins -s ./kong.yaml -o ./kong.yaml kong-plugins/*

echo "*** 4. Add tag ***"
deck file add-tags -s ./kong.yaml -o ./kong.yaml $TAG

echo "*** 5. Back up current settings ***"
deck gateway dump -o ./current-kong-$(date +"%Y-%m-%d_%H-%M-%S").yaml --konnect-addr $KONNECT_URL --konnect-control-plane-name $CONTROL_PLANE --konnect-token $KONNECT_TOKEN

echo "*** 6. Check difference ***"
deck gateway diff ./kong.yaml --konnect-addr $KONNECT_URL --konnect-control-plane-name $CONTROL_PLANE --konnect-token $KONNECT_TOKEN --select-tag $TAG

# Ask if the sync should proceed
read -p "Do you want to sync the API Spec to Konnect now? (y/n): " answer

if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
  echo "*** 7. Sync API Spec to Konnect ***"
  deck gateway sync ./kong.yaml --konnect-addr $KONNECT_URL --konnect-control-plane-name $CONTROL_PLANE --konnect-token $KONNECT_TOKEN --select-tag $TAG
else
  echo "Sync aborted."
fi