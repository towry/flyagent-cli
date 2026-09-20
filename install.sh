#!/usr/bin/env bash
# Install the flyagent CLI from the towry/flyagent-cli release assets.
#
#   curl -fsSL https://raw.githubusercontent.com/towry/flyagent-cli/main/install.sh | bash
#
# Pin a release or choose the target directory:
#
#   curl -fsSL .../install.sh | bash -s -- --version v1.0.0
#   curl -fsSL .../install.sh | bash -s -- --dir /usr/local/bin
#
# The script resolves the release tag, downloads the tarball for this OS and
# architecture, verifies it against the release checksums.txt, and installs the
# flyagent binary.
set -euo pipefail

REPO="towry/flyagent-cli"
VERSION=""
# Empty when HOME is unset, so the check below can report it clearly.
DIR="${HOME:+${HOME}/.local/bin}"

usage() {
	cat <<'EOF'
Install the flyagent CLI.

Usage: install.sh [--version <tag>] [--dir <directory>]

  --version <tag>    release tag to install (default: the latest release)
  --dir <directory>  where the flyagent binary goes (default: $HOME/.local/bin)
  -h, --help         show this help

Set GITHUB_TOKEN to authenticate the release lookup when the anonymous GitHub
API rate limit is too low, for example on a shared CI runner.
EOF
}

die() {
	echo "install.sh: $*" >&2
	exit 1
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--version)
			[[ $# -ge 2 ]] || die "--version needs a release tag"
			VERSION="$2"
			shift 2
			;;
		--dir)
			[[ $# -ge 2 ]] || die "--dir needs a directory"
			DIR="$2"
			shift 2
			;;
		-h | --help)
			usage
			exit 0
			;;
		*) die "unknown argument: $1 (try --help)" ;;
	esac
done

[[ -n "$DIR" ]] || die "HOME is not set; pass --dir"

os="$(uname -s)"
case "$os" in
	Linux) os=linux ;;
	Darwin) os=darwin ;;
	*) die "unsupported OS: $os (releases cover linux and darwin)" ;;
esac

arch="$(uname -m)"
case "$arch" in
	x86_64 | amd64) arch=amd64 ;;
	arm64 | aarch64) arch=arm64 ;;
	*) die "unsupported architecture: $arch" ;;
esac

command -v curl >/dev/null || die "curl is required"
command -v tar >/dev/null || die "tar is required"
if command -v sha256sum >/dev/null; then
	sha256=(sha256sum)
elif command -v shasum >/dev/null; then
	sha256=(shasum -a 256)
else
	die "sha256sum or shasum is required to verify the download"
fi

auth=()
[[ -n "${GITHUB_TOKEN:-}" ]] && auth=(-H "Authorization: Bearer ${GITHUB_TOKEN}")

if [[ -z "$VERSION" ]]; then
	json="$(curl -fsSL "${auth[@]}" "https://api.github.com/repos/${REPO}/releases/latest")" ||
		die "could not read the latest release of ${REPO} (no release yet, or the GitHub API is unreachable)"
	VERSION="$(printf '%s' "$json" | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p')"
	[[ -n "$VERSION" ]] || die "could not read the latest release tag of ${REPO}"
fi

asset="flyagent_${VERSION}_${os}_${arch}.tar.gz"
base="https://github.com/${REPO}/releases/download/${VERSION}"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "downloading ${asset}"
curl -fsSL "${auth[@]}" "${base}/${asset}" -o "${tmp}/${asset}" ||
	die "download failed: ${base}/${asset}"
curl -fsSL "${auth[@]}" "${base}/checksums.txt" -o "${tmp}/checksums.txt" ||
	die "download failed: ${base}/checksums.txt"

(cd "$tmp" && grep -F "  ${asset}" checksums.txt | "${sha256[@]}" -c -) ||
	die "checksum verification failed for ${asset}"

tar -xzf "${tmp}/${asset}" -C "$tmp" flyagent

mkdir -p "$DIR"
[[ -w "$DIR" ]] || die "${DIR} is not writable; pass --dir or re-run with sudo"
# Install through a temporary name in the target directory: mv is atomic and
# keeps working when the flyagent that is being replaced is still running.
staged="${DIR}/.flyagent.$$"
cp "${tmp}/flyagent" "$staged"
chmod 0755 "$staged"
mv -f "$staged" "${DIR}/flyagent"

echo "installed ${DIR}/flyagent (${VERSION})"
case ":${PATH}:" in
	*":${DIR}:"*) ;;
	*) echo "note: ${DIR} is not in PATH; add it with: export PATH=\"${DIR}:\$PATH\"" ;;
esac
