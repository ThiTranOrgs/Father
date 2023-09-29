#!/bin/bash

TOKEN=$1
REPO_NAME=$2
CONTRACT_OWNER=$3
ORG_OWNER=$4
ISSUE_NUMBER=$5
NODE_RPC="--node tcp://tencent.blockchain.testnet.sharetoken.io:26657/ --chain-id ShareRing-LifeStyle"
SUBMITSION_REPO="Father"

curl -L https://github.com/ShareRing/Shareledger/releases/download/v2.0.1/shareledger --output shareledger
chmod 755 shareledger
sudo mv shareledger /usr/bin/shareledger
which shareledger

shareledger q wasm code-info $REPO_NAME $NODE_RPC &>/dev/null
RETURN_CODE=$?
if [ $RETURN_CODE -ne 0 ]; then
	echo "Repository name must be code id of smart contract that deployed on blockchain."
	exit 1
fi

# Create new repository for user to upload their contract code
RETURN_CODE=$(curl -L -s -o /dev/null -w "%{http_code}" \
	-X POST \
	-H "Accept: application/vnd.github+json" \
	-H "Authorization: Bearer $TOKEN" \
	-H "X-GitHub-Api-Version: 2022-11-28" \
	https://api.github.com/repos/$ORG_OWNER/Template/generate \
	-d "{\"owner\":\"$ORG_OWNER\",\"name\":\"$REPO_NAME\",\"include_all_branches\":false,\"private\":false}")

if [ $RETURN_CODE -ne 201 ]; then
	echo "failed to create new repository with return code: $RETURN_CODE. Hint: it might existed!"
	exit 1
fi

# Send a invitation to contract owner account to be a repository collaborator
RETURN_CODE=$(curl -L -s -o /dev/null -w "%{http_code}" \
	-X PUT \
	-H "Accept: application/vnd.github+json" \
	-H "Authorization: Bearer $TOKEN" \
	-H "X-GitHub-Api-Version: 2022-11-28" \
	https://api.github.com/repos/$ORG_OWNER/$REPO_NAME/collaborators/$CONTRACT_OWNER \
	-d '{"permission":"push"}')

if [ $RETURN_CODE -ne 201 ]; then
	echo "failed to invite collaborator!"
	exit 1
fi

RETURN_CODE=$(curl -L -s -o /dev/null -w "%{http_code}" \
	-X PATCH \
	-H "Accept: application/vnd.github+json" \
	-H "Authorization: Bearer $TOKEN" \
	-H "X-GitHub-Api-Version: 2022-11-28" \
	https://api.github.com/repos/$ORG_OWNER/$SUBMITSION_REPO/issues/$ISSUE_NUMBER \
	-d '{"state":"closed"}')

if [ $RETURN_CODE -ne 200 ]; then
	echo "failed to close issue number $ISSUE_NUMBER of $ORG_OWNER/$REPO_NAME"
	exit -1
fi
