# Parent

> Trigger action on issue 'opened' envent to create new repository and invite contract owner as a collaborator of the new repository
> Trigger action to build and verify contract binary against checksum save on blockchain

# What contract owner need to do

> Open an issue on this repo: https://github.com/ThiTranOrgs/Father
> Wait for the github workflow create new repository and send an collaborator invitation to your email or github account. You have to accept this email to be able to push code, create new release ...
> You can create new release whenever your code is ready to verify checksum against the checksum of your contract on blockchain.
>
> > Note: the release name and release tag name must be the same and sastify semantic versioning.
> > Your release will be verified after a few minutes. If it pass you will able to see your release body contain the checksum and a signature sign by ShareRing and the valid repository commit link will be show on our Explorer.
