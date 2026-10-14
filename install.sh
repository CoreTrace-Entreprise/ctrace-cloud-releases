#!/bin/sh
# Installs ctrace-cloud from the public releases, checking the SHA-256 checksum and, when cosign
# is on PATH, the signed checksums manifest.
# Usage: curl -fsSL <install.sh url> | sh
# Env: CORETRACE_VERSION (tag such as 0.2.0, default latest), CORETRACE_INSTALL_DIR,
# CORETRACE_DOWNLOAD_URL
set -eu

# Wrapped in main and called on the last line: a download cut short by a dropped connection
# then fails to parse instead of running half the script.
main() {

  fail() { printf 'install.sh: %s\n' "$*" >&2; exit 1; }
  get() { curl -fsSL -o "$2" "$1" || fail "could not download $1"; }

  command -v curl >/dev/null 2>&1 || fail "curl is required"
  base=${CORETRACE_DOWNLOAD_URL:-https://github.com/CoreTrace-Entreprise/ctrace-cloud-releases/releases}
  dir=${CORETRACE_INSTALL_DIR:-$HOME/.local/bin}
  version=${CORETRACE_VERSION:-}
  if [ -n "$version" ]; then
    case "$version" in v*) ;; *) version="v$version" ;; esac
    url="$base/download/$version"
  else
    url="$base/latest/download"
  fi

  case "$(uname -s)" in
    Linux) os=linux ;;
    Darwin) os=darwin ;;
    *) fail "unsupported OS $(uname -s); on Windows use install.ps1" ;;
  esac
  case "$(uname -m)" in
    x86_64 | amd64) arch=amd64 ;;
    arm64 | aarch64) arch=arm64 ;;
    *) fail "unsupported architecture $(uname -m)" ;;
  esac
  asset="ctrace-cloud-$os-$arch"

  if command -v sha256sum >/dev/null 2>&1; then
    sha256() { sha256sum "$1" | awk '{print $1}'; }
  elif command -v shasum >/dev/null 2>&1; then
    sha256() { shasum -a 256 "$1" | awk '{print $1}'; }
  else
    fail "sha256sum or shasum is required"
  fi

  tmp=$(mktemp -d)
  stage=
  trap 'rm -rf "$tmp" ${stage:+"$stage"}' EXIT
  trap 'exit 1' INT TERM

  get "$url/$asset" "$tmp/$asset"
  get "$url/SHA256SUMS" "$tmp/SHA256SUMS"
  expected=$(awk -v f="$asset" '$2 == f {print $1}' "$tmp/SHA256SUMS")
  [ -n "$expected" ] || fail "SHA256SUMS has no entry for $asset"
  actual=$(sha256 "$tmp/$asset")
  [ "$actual" = "$expected" ] || fail "checksum mismatch for $asset: expected $expected, got $actual"

  if command -v cosign >/dev/null 2>&1; then
    get "$url/SHA256SUMS.sigstore.json" "$tmp/SHA256SUMS.sigstore.json"
    cosign verify-blob --bundle "$tmp/SHA256SUMS.sigstore.json" \
      --certificate-identity-regexp '^https://github.com/CoreTrace-Entreprise/coretrace-cli/\.github/workflows/release\.yml@refs/tags/v[0-9]' \
      --certificate-oidc-issuer https://token.actions.githubusercontent.com "$tmp/SHA256SUMS" >/dev/null \
      || fail "signature check failed for SHA256SUMS"
  else
    printf 'cosign not found, release signature not checked\n' >&2
  fi

  mkdir -p "$dir"
  dir=$(cd "$dir" && pwd)
  stage=$(mktemp "$dir/.ctrace-cloud.XXXXXX")
  cp "$tmp/$asset" "$stage"
  chmod 755 "$stage"
  # Same-directory rename is atomic, so a re-run also replaces a binary that is currently running.
  mv -f "$stage" "$dir/ctrace-cloud"
  printf 'Installed ctrace-cloud %s to %s\n' "${version:-latest}" "$dir/ctrace-cloud"
  case ":$PATH:" in
    *":$dir:"*) ;;
    *) printf 'Add %s to your PATH: export PATH="%s:$PATH"\n' "$dir" "$dir" ;;
  esac
}

main "$@"
