#!/bin/bash

ORGS_OWNER="$1"
REPO_NAME="$2"
REPO_DIR="src/$REPO_NAME"
REPO_LINK="https://github.com/$ORGS_OWNER/$REPO_NAME.git"

curl -L https://github.com/ShareRing/Shareledger/releases/download/v2.0.1/shareledger --output shareledger
chmod 755 shareledger
sudo mv shareledger /usr/bin/shareledger
which shareledger

sudo apt-get update
sudo apt-get install -y git
sudo apt-get install -y jq

git clone $REPO_LINK $REPO_DIR

exit 0
