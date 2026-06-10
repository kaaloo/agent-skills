# Security model for remote-worker signed commits

A verified Git commit proves that whoever controlled the signing capability approved that exact commit object. It does not prove where the code was written.

## Recommended pattern

Use remote environments as code producers and local machines as signing authorities:

1. Remote worker pushes a branch or produces a patch.
2. Local machine fetches the branch.
3. Local agent/user reviews the diff against the base branch.
4. Local machine recreates the diff as a signed commit using the user's configured SSH/GPG signing setup.
5. Local machine updates the PR branch using `--force-with-lease`.

This preserves remote productivity without exporting personal signing keys.

## Avoid storing personal signing keys in cloud workers

A signing key is identity material. Even if a signing-only SSH key cannot push to GitHub, compromise of that key allows forged commits that GitHub may display as verified for the user's account until the key is revoked.

## Acceptable alternatives

- **Dedicated bot identity**: Give the remote worker a bot signing key and repo-scoped push credential. Commits are verified as the bot, optionally with `Co-authored-by` trailers for humans.
- **GitHub squash merge**: Let remote workers open PRs and rely on protected-branch merges created through GitHub. This keeps `main` clean but does not make PR branch commits personally signed.
- **Policy signing service**: A local or controlled signer can sign requested commits only after validating repository, branch, diff, and human approval. Avoid blind SSH-agent forwarding.

## Red flags

- Plain `git push --force` instead of `--force-with-lease`.
- Signing commits in a runtime that does not clearly have the user's trusted key/agent.
- Uploading a personal private SSH/GPG key to a general-purpose worker.
- Signing a branch without reviewing the diff produced remotely.
