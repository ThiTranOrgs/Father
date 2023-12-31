#!/bin/bash

CONTRACT_NAME_REPO=$1
TOKEN="$2"
GITHUB_USER_NAME="$3"
RELEASE_ID="$4"
PRIVATE_KEY="$5"
PRIVKEY_FILE="$6"

ROOT_DIR="$PWD"
CONTRACT_DIR="$ROOT_DIR/src"
SOURCE_DIR="$CONTRACT_DIR/$CONTRACT_NAME_REPO/src"
CONTRACT_NAME_FILE="$CONTRACT_DIR/$CONTRACT_NAME_REPO/CONTRACT_NAME"
RUST_IMAGE_FILE="$CONTRACT_DIR/$CONTRACT_NAME_REPO/IMAGE_BUILDER"
CODE_ID_FILE="$CONTRACT_DIR/$CONTRACT_NAME_REPO/CODE_ID"
ARTIFACTS="$SOURCE_DIR/artifacts"
NODE_RPC="--node tcp://tencent.blockchain.testnet.sharetoken.io:26657/ --chain-id ShareRing-LifeStyle"
SHARELEDGER_BIN="shareledger"
ENCRYPTED_CHECKSUM_FILE="/tmp/checksum.dat"
# TODO: Update path to secrets
CODE_ID=$(<$CODE_ID_FILE)

# Check for required files
if [ ! -s $CONTRACT_NAME_FILE ] || [ ! -s $RUST_IMAGE_FILE ] || [ ! -s $CODE_ID_FILE ]; then
	echo "The required files $CONTRACT_NAME_FILE or $RUST_IMAGE_FILE not found"
	exit 1
fi

# Clean up old artifacts if any
if [ ! -d "$SOURCE_DIR/artifacts" ]; then
	rm -f $SOURCE_DIR/artifacts/*
fi

CONTRACT_NAME="$(<$CONTRACT_NAME_FILE)"
IMAGE="$(<$RUST_IMAGE_FILE)"

pushd $SOURCE_DIR

echo "Compiling $CONTRACT_NAME smart contract ..."
# Build specific contract
if [ ! -d "$SOURCE_DIR/contracts/$CONTRACT_NAME" ]; then
	echo "No such file $SOURCE_DIR/contracts/$CONTRACT_NAME"
	exit 1
fi

# To compile specific contracts, the cosmwasm/rust-optimizer* image must be used instead of cosmwasm/workspace-optimizer* image
if [[ "$IMAGE" != *"rust-optimizer"* ]]; then
	echo "Must use cosmwasm/rust-optimizer* image when compile specific contract. Got $IMAGE"
	exit 1
fi

docker run --rm -v "$(pwd)":/code \
	--mount type=volume,source="devcontract_cache_$CONTRACT_NAME",target=/code/contracts/$CONTRACT_NAME/target \
	--mount type=volume,source=registry_cache,target=/usr/local/cargo/registry \
	$IMAGE ./contracts/$CONTRACT_NAME

popd

# Verify contract
echo "Verifying contract checksum ..."
GET_LOCAL_CHECKSUM_CMD="cat $ARTIFACTS/checksums.txt | head -n1 | cut -d \" \" -f1"
GET_BLOCK_CHAIN_CHECKSUM_CMD="$SHARELEDGER_BIN q wasm code-info $CODE_ID $NODE_RPC | grep data_hash |  cut -d \" \" -f2 | tr '[:upper:]' '[:lower:]'"

LOCAL_CHECKSUM=$(eval $GET_LOCAL_CHECKSUM_CMD)
BLOCK_CHAIN_CHECKSUM=$(eval $GET_BLOCK_CHAIN_CHECKSUM_CMD)

echo "local_checksum: $LOCAL_CHECKSUM  blockchain_checksum: $BLOCK_CHAIN_CHECKSUM"
if [ "$LOCAL_CHECKSUM" = "$BLOCK_CHAIN_CHECKSUM" ]; then
	# Encrypt checksumm
	echo -n "$PRIVATE_KEY" | base64 -d >$PRIVKEY_FILE
	echo -n "$LOCAL_CHECKSUM" | openssl dgst -sha256 -sign $PRIVKEY_FILE -out $ENCRYPTED_CHECKSUM_FILE
	BASE_64=$(openssl base64 -in $ENCRYPTED_CHECKSUM_FILE -A)
	# Remove encrypted checksum output file
	rm -f $ENCRYPTED_CHECKSUM_FILE $PRIVKEY_FILE

	# Query repository with name
	FULL_REPO_NAME=$(curl -L -s https://api.github.com/users/$GITHUB_USER_NAME/repos | jq '.[].full_name' | grep $CONTRACT_NAME_REPO)
	FULL_REPO_NAME=${FULL_REPO_NAME//\"/}
	GET_LATEST_COMMIT_HASH_CMD="curl -L -s \
  -H \"Accept: application/vnd.github.sha\" \
  -H \"Authorization: $TOKEN\" \
  -H \"X-GitHub-Api-Version: 2022-11-28\" \
  https://api.github.com/repos/$FULL_REPO_NAME/commits/main"
	COMMIT_HASH=$(eval $GET_LATEST_COMMIT_HASH_CMD)
	echo $COMMIT_HASH | grep -q "Not Found"
	RETURN_CODE=$?
	if [ $RETURN_CODE -eq 0 ]; then
		echo "failed to get commit hash of $FULL_REPO_NAME"
		exit 1
	fi

	echo "Verify checksum successfully, update release ..."
	RETURN_CODE=$(curl -L -X PATCH \
		-H "Accept: application/vnd.github+json" \
		-H "Authorization: Bearer $TOKEN" \
		-H "X-GitHub-Api-Version: 2022-11-28" \
		https://api.github.com/repos/$FULL_REPO_NAME/releases/$RELEASE_ID \
		-d "{\"target_commitish\":\"$COMMIT_HASH\",\"body\":\"${LOCAL_CHECKSUM}_${BASE_64}\"}")
	if [ $RETURN_CODE -ne 200 ]; then
		echo "failed to update release for $FULL_REPO_NAME"
		exit 1
	fi
else
	echo "The local checksum not matches with the checksum stored on blockchain"
	exit 1
fi
