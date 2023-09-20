#!/bin/bash

TOKEN=$1
REPO_NAME=$2
CONTRACT_OWNER=$3
ORG_OWNER=$4

#TODO: Check if repo exist

#TODO: Check fot CONTRACT_OWNER account

# Create new repository for user to upload their contract code
curl -L \
	-X POST \
	-H "Accept: application/vnd.github+json" \
	-H "Authorization: Bearer $TOKEN" \
	-H "X-GitHub-Api-Version: 2022-11-28" \
	https://api.github.com/repos/$ORG_OWNER/Template/generate \
	-d "{\"owner\":\"$ORG_OWNER\",\"name\":\"$REPO_NAME\",\"include_all_branches\":false,\"private\":false}"

RETURN_CODE=$?
if [ $RETURN_CODE -ne 0 ]; then
	echo "failed to create new repository!"
	return 1
fi

# Send a invitation to contract owner account to be an organiztion members
# curl -L \
# 	-X POST \
# 	-H "Accept: application/vnd.github+json" \
# 	-H "Authorization: Bearer $TOKEN" \
# 	-H "X-GitHub-Api-Version: 2022-11-28" \
# 	https://api.github.com/orgs/$ORG_OWNER/invitations \
# 	-d "{\"invitee_id\":$CONTRACT_OWNER,\"role\":\"direct_member\"}"

# Send a invitation to contract owner account to be a repository collaborator
curl -L \
	-X PUT \
	-H "Accept: application/vnd.github+json" \
	-H "Authorization: Bearer $TOKEN" \
	-H "X-GitHub-Api-Version: 2022-11-28" \
	https://api.github.com/repos/$ORG_OWNER/$REPO_NAME/collaborators/$CONTRACT_OWNER \
	-d '{"permission":"push"}'

RETURN_CODE=$?
if [ $RETURN_CODE -ne 0 ]; then
	echo "failed to create new repository!"
	return 1
fi
