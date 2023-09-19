#!/bin/bash

TOKEN=$1
REPO_NAME=$2
CONTRACT_OWNER=$3
ORG_OWNER=$4

#TODO: Check if repo exist

#TODO: Check fot CONTRACT_OWNER account

# Create new repository for user to upload their contract code
gh api \
	--method POST \
	-H "Accept: application/vnd.github+json" \
	-H "Authorization: $TOKEN" \
	-H "X-GitHub-Api-Version: 2022-11-28" \
	/repos/$ORG_OWNER/Template/generate \
	-f owner="$ORG_OWNER" \
	-f name="$REPO_NAME" \
	-F include_all_branches=false \
	-F private=false

RETURN_CODE=$?
if [ $RETURN_CODE -ne 0 ]; then
	echo "failed to create new repository!"
	return 1
fi

# Send a invitation to contract owner account
curl -L \
	-X POST \
	-H "Accept: application/vnd.github+json" \
	-H "Authorization: Bearer $TOKEN" \
	-H "X-GitHub-Api-Version: 2022-11-28" \
	https://api.github.com/orgs/$ORG_OWNER/invitations \
	-d '{"invitee_id":"$CONTRACT_OWNER","role":"direct_member"}'
