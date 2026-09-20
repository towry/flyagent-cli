# flyagent-cli

Release binaries and the installer for the **flyagent** CLI.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/towry/flyagent-cli/main/install.sh | bash
```

Linux and macOS on amd64 and arm64. The installer resolves the latest release,
verifies the tarball against `checksums.txt`, and installs `flyagent` into
`$HOME/.local/bin`.

Pass `--version <tag>` to pin a release, `--dir <directory>` to install
elsewhere, or set `GITHUB_TOKEN` for the release lookup on a shared CI runner.

## Releases

Push a tag to this repository and `.github/workflows/release.yml` builds the CLI
from the source repository's current `main` commit and publishes it under that
tag, with `flyagent_<tag>_<os>_<arch>.tar.gz`, `checksums.txt`, and
`install.sh`. A tag whose release already exists stops before building.

The binary carries the client commands (`publish`, `fetch-secret`, `secret`);
the server is not part of this release.

The workflow needs one repository secret: `FLYAGENT_DEPLOY_KEY` (read-only
deploy key of the source repository) or `FLYAGENT_REPO_TOKEN` (fine-grained PAT
with Contents: Read).
