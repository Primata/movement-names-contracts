#!/bin/sh

set -e

echo "##### Publishing packages #####"
# Set these to the account address you want to deploy to.
MOVEMENT_NAMES="_"
MOVEMENT_NAMES="_"
BULK="_"
ADMIN="_"
FUNDS="_"
ROUTER="_"

ROUTER_SIGNER=0x$(aptos account derive-resource-account-address \
  --address $ROUTER \
  --seed "MNS ROUTER" \
  --seed-encoding utf8 | \
  grep "Result" | \
  sed -n 's/.*"Result": "\([^"]*\)".*/\1/p')

aptos move publish \
  --profile core_profile \
  --package-dir core \
  --named-addresses movement_names=$MOVEMENT_NAMES,movement_names_admin=$ADMIN,movement_names_funds=$FUNDS,router_signer=$ROUTER_SIGNER
aptos move publish \
  --profile core_v2_profile \
  --package-dir core_v2 \
  --named-addresses movement_names=$MOVEMENT_NAMES,movement_names=$MOVEMENT_NAMES,movement_names_admin=$ADMIN,movement_names_funds=$FUNDS,router=$ROUTER,router_signer=$ROUTER_SIGNER
aptos move publish \
  --profile router_profile \
  --package-dir router \
  --named-addresses movement_names=$MOVEMENT_NAMES,movement_names=$MOVEMENT_NAMES,movement_names_admin=$ADMIN,movement_names_funds=$FUNDS,router=$ROUTER,router_signer=$ROUTER_SIGNER
aptos move publish \
  --profile bulk_profile \
  --package-dir bulk \
  --named-addresses movement_names=$MOVEMENT_NAMES,movement_names=$MOVEMENT_NAMES,movement_names_admin=$ADMIN,movement_names_funds=$FUNDS,router=$ROUTER,router_signer=$ROUTER_SIGNER,bulk=$BULK
