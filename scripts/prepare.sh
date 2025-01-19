#!/bin/bash

if [ -f .env ]; then
    source .env
fi

# envs
VERSION=${VERSION:?"Must set `VERSION` in .env"}
GENESIS_OUTPUT_DIR=${GENESIS_OUTPUT_DIR:?"Must set `GENESIS_OUTPUT_DIR` in .env"}
DATA_DIR=${DATA_DIR:?"Must set `DATA_DIR` in .env"}

RELAY_CHAIN_SEPC=${RELAY_CHAIN_SEPC:?"Must set `RELAY_CHAIN_SEPC` in .env"}
ASSET_HUB_CHAIN_SEPC=${ASSET_HUB_CHAIN_SEPC:?"Must set `ASSET_HUB_CHAIN_SEPC` in .env"}

mkdir -p ${GENESIS_OUTPUT_DIR}
mkdir -p ${DATA_DIR}

# local envs
REALY_CHAIN_IMAGE_NAME="parity/polkadot:${VERSION}"
ASSET_HUB_CHAIN_IMAGE_NAME="parity/polkadot-parachain:${VERSION}"

RELAY_CHAIN_SEPC_FILE=${RELAY_CHAIN_SEPC}.json
ASSET_HUB_CHAIN_SEPC_FILE=${ASSET_HUB_CHAIN_SEPC}.json

RELAY_CHAIN_SEPC_PATH=${GENESIS_OUTPUT_DIR}/${RELAY_CHAIN_SEPC_FILE}
ASSET_HUB_CHAIN_SEPC_PATH=${GENESIS_OUTPUT_DIR}/${ASSET_HUB_CHAIN_SEPC_FILE}

echo "*****************************Step1: Pulling docker images*****************************"
echo "Pulling:" ${REALY_CHAIN_IMAGE_NAME}
docker pull ${REALY_CHAIN_IMAGE_NAME}

echo "Pulling:" ${ASSET_HUB_CHAIN_IMAGE_NAME}
docker pull ${ASSET_HUB_CHAIN_IMAGE_NAME}
echo ""

echo "*****************************Step2: Generating bootnodes*****************************"
echo "Generating relaychain bootnode..."
docker run --rm \
    -v ${GENESIS_OUTPUT_DIR}:/genesis \
    ${REALY_CHAIN_IMAGE_NAME} \
    key generate-node-key --file=/genesis/relaychain-bootnode.key > ${GENESIS_OUTPUT_DIR}/relaychain-bootnode-id 2>&1

relaychain_bootnode=/ip4/127.0.0.1/tcp/30333/p2p/$(cat ${GENESIS_OUTPUT_DIR}/relaychain-bootnode-id)
echo "relaychain_bootnode: ${relaychain_bootnode}"

echo "Generating asset-hub bootnode..."
docker run --rm \
    -v ${GENESIS_OUTPUT_DIR}:/genesis \
    ${ASSET_HUB_CHAIN_IMAGE_NAME} \
    key generate-node-key --file=/genesis/asset-hub-bootnode.key > ${GENESIS_OUTPUT_DIR}/asset-hub-bootnode-id 2>&1

asset_hub_bootnode=/ip4/127.0.0.1/tcp/30333/p2p/$(cat ${GENESIS_OUTPUT_DIR}/asset-hub-bootnode-id)
echo "asset_hub_bootnode: ${asset_hub_bootnode}"
echo ""

echo "*****************************Step3: Generating genesis*****************************"
echo "Generating relaychain genesis..."
docker run --rm -v ${GENESIS_OUTPUT_DIR}:/genesis \
    ${REALY_CHAIN_IMAGE_NAME} \
    build-spec --chain=rococo-local --node-key-file=/genesis/relaychain-bootnode.key > ${RELAY_CHAIN_SEPC_PATH}

echo "Generating asset-hub-parachain genesis..."
docker run --rm -v ${GENESIS_OUTPUT_DIR}:/genesis \
    ${ASSET_HUB_CHAIN_IMAGE_NAME} \
    build-spec --chain=asset-hub-rococo-local --node-key-file=/genesis/asset-hub-bootnode.key > ${ASSET_HUB_CHAIN_SEPC_PATH}
echo ""

echo "*****************************Step3.1: Update parachain bootnode to new port*****************************"
echo "update asset hub chain spec bootnode port to a new one..."
sed -i 's/\/ip4\/127.0.0.1\/tcp\/30333/\/ip4\/127.0.0.1\/tcp\/31333/' ${ASSET_HUB_CHAIN_SEPC_PATH}
echo "Now it's:"
head -n 7 ${ASSET_HUB_CHAIN_SEPC_PATH}
echo ""

echo "*****************************Step4: Exporting genesis state & wasm*****************************"
echo "Exporting genesis state for asset-hub-parachain..."
docker run --rm \
    -v ${ASSET_HUB_CHAIN_SEPC_PATH}:/genesis/${ASSET_HUB_CHAIN_SEPC_FILE} \
    ${ASSET_HUB_CHAIN_IMAGE_NAME} \
    export-genesis-state --chain=/genesis/${ASSET_HUB_CHAIN_SEPC_FILE} > ${GENESIS_OUTPUT_DIR}/${ASSET_HUB_CHAIN_SEPC}-state

echo "Exporting genesis state for asset-hub-parachain..."
docker run --rm \
    -v ${ASSET_HUB_CHAIN_SEPC_PATH}:/genesis/${ASSET_HUB_CHAIN_SEPC_FILE} \
    ${ASSET_HUB_CHAIN_IMAGE_NAME} \
    export-genesis-wasm --chain=/genesis/${ASSET_HUB_CHAIN_SEPC_FILE} > ${GENESIS_OUTPUT_DIR}/${ASSET_HUB_CHAIN_SEPC}-wasm
