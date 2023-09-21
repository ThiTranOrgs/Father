#!/bin/bash

TODO: Update to real repository name
CONTRACT_NAME_REPO=$1
TOKEN="$2"
USER_NAME="$3"

ROOT_DIR="$PWD"
CONTRACT_DIR="$ROOT_DIR/src"
#TODO: specific real directory
SOURCE_DIR="$CONTRACT_DIR/$CONTRACT_NAME_REPO/src"
CONTRACT_NAME_FILE="$CONTRACT_DIR/$CONTRACT_NAME_REPO/CONTRACT_NAME"
RUST_IMAGE_FILE="$CONTRACT_DIR/$CONTRACT_NAME_REPO/IMAGE_BUILDER"
IS_PUBLIC_REPO="$CONTRACT_DIR/$CONTRACT_NAME_REPO/IS_PUBLIC_REPO"
CODE_ID_FILE="$CONTRACT_DIR/$CONTRACT_NAME_REPO/CODE_ID"
ARTIFACTS="$SOURCE_DIR/artifacts"
NODE_RPC="--node tcp://tencent.blockchain.testnet.sharetoken.io:26657/ --chain-id ShareRing-LifeStyle"
#TODO: The github workflow need to curl the shareledger binary
SHARELEDGER_BIN="shareledger"
#TODO: Update ShareRing github user name
CODE_ID=$(<$CODE_ID_FILE)
#TODO: Will use secrets instead

# Check for required files
if [ ! -f $CONTRACT_NAME_FILE ] || [ ! -f $RUST_IMAGE_FILE ] || [ ! -f $IS_PUBLIC_REPO ] || [ ! -f $CODE_ID_FILE ]; then
	echo "The required files $CONTRACT_NAME_FILE or $RUST_IMAGE_FILE not found"
	exit 1
fi

# Clean up old artifacts
if [ ! -d "$SOURCE_DIR/artifacts" ]; then
	rm -f $SOURCE_DIR/artifacts/*
fi

# TODO: Improve to search only for dir name with number instead of *
CONTRACT_NAME="$(<$CONTRACT_NAME_FILE)"
IMAGE="$(<$RUST_IMAGE_FILE)"
IS_PUBLIC="$(<$IS_PUBLIC_REPO)"

# Build new image base on cosmwasm/rust-optimizer image with include the private key to access private repository (ie: bitbucket.org).
# Only private repository use this step, so the code will not be public.

pushd $SOURCE_DIR

# Build all contracts in a workspace
if [ "$CONTRACT_NAME" = "" ]; then
	echo "Compiling smart contracts for a workspace ..."
	docker run --rm -v "$(pwd)":/code \
		--mount type=volume,source="$(basename "$(pwd)")_cache",target=/target \
		--mount type=volume,source=registry_cache,target=/usr/local/cargo/registry \
		$IMAGE
else
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
fi

popd

# Verify contract
echo "Verifying contract checksum ..."
GET_LOCAL_CHECKSUM_CMD="cat $ARTIFACTS/checksums.txt | grep ${CONTRACT_NAME//-/_} | head -n1 | cut -d \" \" -f1"
GET_BLOCK_CHAIN_CHECKSUM_CMD="$SHARELEDGER_BIN q wasm code-info $CODE_ID $NODE_RPC | grep data_hash |  cut -d \" \" -f2 | tr '[:upper:]' '[:lower:]'"

LOCAL_CHECKSUM=$(eval $GET_LOCAL_CHECKSUM_CMD)
BLOCK_CHAIN_CHECKSUM=$(eval $GET_BLOCK_CHAIN_CHECKSUM_CMD)

echo "local_checksum: $LOCAL_CHECKSUM  blockchain_checksum: $BLOCK_CHAIN_CHECKSUM"
if [ "$LOCAL_CHECKSUM" = "$BLOCK_CHAIN_CHECKSUM" ]; then

	echo "Verify checksum successfully, create release tag ..."
	# Query repository with name
	FULL_REPO_NAME=$(curl -L -s https://api.github.com/users/$USER_NAME/repos | jq '.[].full_name' | grep $CONTRACT_NAME)
	FULL_REPO_NAME=${FULL_REPO_NAME//\"/}

	GET_LATEST_COMMIT_HASH_CMD="curl -L -s \
  -H \"Accept: application/vnd.github.sha\" \
  -H \"Authorization: Bearer ghu_NIGXUrVVAhyX96CVk9zI4dfMZHJhUt4T6nUf\" \
  -H \"X-GitHub-Api-Version: 2022-11-28\" \
  https://api.github.com/repos/$FULL_REPO_NAME/commits/main"

	COMMIT_HASH=$(eval $GET_LATEST_COMMIT_HASH_CMD)
	RETURN_CODE=$?
	if [ $RETURN_CODE -ne 0 ]; then
		echo "failed to get commit hash of $FULL_REPO_NAME"
		return 1
	fi

	# Make a release only if the repository did not released
	CHECK_RELEASE_CMD="curl -L -s \
  -H \"Accept: application/vnd.github+json\" \
  -H \"X-GitHub-Api-Version: 2022-11-28\" \
  https://api.github.com/repos/$FULL_REPO_NAME/releases/latest"

	RELEASE=$(eval $CHECK_RELEASE_CMD)
	echo "==== $COMMIT_HASH ==== $FULL_REPO_NAME ==== $RELEASE"
	echo $RELEASE | grep -q "Not Found"
	RETURN_CODE=$?
	# Make release in case no release yet
	if [ $RETURN_CODE -eq 0 ]; then
		echo "RELEASE: $USER_NAME==========="
		curl -L -s -X POST \
			-H "Accept: application/vnd.github+json" \
			-H "Authorization: $TOKEN" \
			-H "X-GitHub-Api-Version: 2022-11-28" \
			https://api.github.com/repos/$FULL_REPO_NAME/releases \
			-d "{\"tag_name\":\"verified\",\"target_commitish\":\"$COMMIT_HASH\",\"name\":\"Verified release\",\"body\":\"This $CONTRACT_NAME contract was verified as match with the contract deploy on blockchain!\",\"draft\":false,\"prerelease\":false,\"generate_release_note\":false}"
	fi
else
	exit 1
fi

# Cleanup
rm -rf CONTRACT_DIR="$ROOT_DIR/src/$CONTRACT_NAME"
