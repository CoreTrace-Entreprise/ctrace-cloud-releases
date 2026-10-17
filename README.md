# ctrace-cloud

`ctrace-cloud` is the command-line client for [CoreTrace](https://app.coretrace.fr). It submits a project to the CoreTrace cloud platform, runs the analysis tools available to your organisation, follows progress and downloads the results.

Use it from your terminal or CI pipeline to:

- Choose analysis tools from your organisation's catalogue.
- Preview which project files would be uploaded.
- Submit cloud analyses and review their CTU estimate.
- Browse findings interactively or export text, JSON, SARIF and GitLab Code Quality reports.
- List jobs, retrieve reports and cancel running jobs.

The analysis runs on CoreTrace infrastructure. The client packages and uploads the selected source files; it needs a network connection, a CoreTrace account or organisation API key, and access to the requested tools. Available languages, tools and limits depend on the platform catalogue and your organisation's plan. CTU is the platform's analysis usage unit.

This repository distributes release binaries, installers and user documentation. It does not contain the client source code. The binaries are standalone: you do not need Node.js, Bun or the analysis tools installed locally.

**Documentation:** [Complete command and flag reference](docs/cli.md) · [Latest release](https://github.com/CoreTrace-Entreprise/ctrace-cloud-releases/releases/latest) · [CoreTrace documentation](https://app.coretrace.fr/docs)

## Choose your platform

| Platform | Processor | Release asset |
| --- | --- | --- |
| Linux | Intel / AMD 64-bit (`x86_64`) | `ctrace-cloud-linux-amd64` |
| Linux | ARM 64-bit (`aarch64`) | `ctrace-cloud-linux-arm64` |
| macOS | Apple Silicon (M-series) | `ctrace-cloud-darwin-arm64` |
| macOS | Intel | `ctrace-cloud-darwin-amd64` |
| Windows | Intel / AMD 64-bit | `ctrace-cloud-windows-amd64.exe` |

The macOS and Linux installer detects your platform and processor. On Apple Silicon, use a native terminal to select the ARM binary. There is no native Windows ARM64 or 32-bit release in v0.3.0.

## Install on macOS

Requires `curl` and `shasum` or `sha256sum`.

```sh
curl -fsSL https://raw.githubusercontent.com/CoreTrace-Entreprise/ctrace-cloud-releases/main/install.sh -o /tmp/ctrace-cloud-install.sh
sh /tmp/ctrace-cloud-install.sh
export PATH="$HOME/.local/bin:$PATH"
ctrace-cloud version
```

The default location is `~/.local/bin/ctrace-cloud`; no administrator access is needed. To keep the command available in new terminals, add the `export PATH` line to your shell startup file (usually `~/.zshrc`).

## Install on Linux

Requires `curl` and `sha256sum` or `shasum`. The installer supports x86-64 and ARM64 Linux.

```sh
curl -fsSL https://raw.githubusercontent.com/CoreTrace-Entreprise/ctrace-cloud-releases/main/install.sh -o /tmp/ctrace-cloud-install.sh
sh /tmp/ctrace-cloud-install.sh
export PATH="$HOME/.local/bin:$PATH"
ctrace-cloud version
```

The default location is `~/.local/bin/ctrace-cloud`; no `sudo` is needed. Add the `export PATH` line to your shell startup file (for example `~/.bashrc` or `~/.zshrc`) for future terminals.

## Install on Windows

Open PowerShell on 64-bit Windows:

```powershell
$installer = Join-Path $env:TEMP 'ctrace-cloud-install.ps1'
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/CoreTrace-Entreprise/ctrace-cloud-releases/main/install.ps1' -OutFile $installer
& $installer
ctrace-cloud version
```

The default location is `%LOCALAPPDATA%\CoreTrace\bin\ctrace-cloud.exe`. The installer adds this directory to your user `Path` and the current session. Administrator access is not required. If your execution policy blocks scripts, follow your organisation's policy or use the manual installation below.

## Pin a version or change the install location

These examples install **v0.3.0**, the release covered by the command reference. Without `CORETRACE_VERSION`, installers select the latest published release.

macOS / Linux:

```sh
CORETRACE_VERSION=v0.3.0 CORETRACE_INSTALL_DIR="$HOME/.local/bin" sh /tmp/ctrace-cloud-install.sh
```

Windows PowerShell:

```powershell
$env:CORETRACE_VERSION = 'v0.3.0'
$env:CORETRACE_INSTALL_DIR = Join-Path $env:LOCALAPPDATA 'CoreTrace\bin'
& $installer
Remove-Item Env:CORETRACE_VERSION
Remove-Item Env:CORETRACE_INSTALL_DIR
```

Installer settings:

| Environment variable | Default | Effect |
| --- | --- | --- |
| `CORETRACE_VERSION` | Latest release | Select a release tag; both `0.3.0` and `v0.3.0` are accepted. |
| `CORETRACE_INSTALL_DIR` | Platform location above | Choose where the executable is installed. Ensure this directory is on `PATH`. |
| `CORETRACE_DOWNLOAD_URL` | This repository's releases URL | Override the release base URL for a mirror using the same asset layout. |

## Manual installation and verification

1. Open the [release page](https://github.com/CoreTrace-Entreprise/ctrace-cloud-releases/releases/latest).
2. Download the binary for your platform and `SHA256SUMS` from the **same release**. Assets are executable files, not archives; the GitHub source archives do not contain the client.
3. Compare the binary's SHA-256 with its entry in `SHA256SUMS`. For example:

   ```sh
   # Linux example
   sha256sum ctrace-cloud-linux-amd64

   # macOS Apple Silicon example
   shasum -a 256 ctrace-cloud-darwin-arm64
   ```

   ```powershell
   Get-FileHash -Algorithm SHA256 .\ctrace-cloud-windows-amd64.exe
   ```

4. On macOS/Linux, rename the downloaded binary to `ctrace-cloud`, make it executable with `chmod +x ctrace-cloud`, then place it in a directory on `PATH`. On Windows, rename it to `ctrace-cloud.exe` and place it in a directory on your user `Path`.
5. Run `ctrace-cloud version`.

The installers always verify the binary checksum. When `cosign` is on `PATH`, they also verify the signature on `SHA256SUMS`; without it, they explicitly report that the signature was not checked. The installer scripts shipped with v0.3.0 do **not** verify SLSA provenance.

Releases also include per-binary Sigstore bundles, `SHA256SUMS.sigstore.json` and `SHA256SUMS.intoto.jsonl` (SLSA provenance). For explicit signature verification with an installed `cosign`, download the manifest and its bundle from one release, then run:

```sh
cosign verify-blob \
  --bundle SHA256SUMS.sigstore.json \
  --certificate-identity 'https://github.com/CoreTrace-Entreprise/coretrace-cli/.github/workflows/release.yml@refs/tags/v0.3.0' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  SHA256SUMS
```

Replace the tag in the certificate identity when verifying another version. After authenticating the manifest, compare its checksum with the binary you downloaded.

## First analysis

Sign in using the device code shown by the client, then inspect the tools available to your organisation:

```sh
ctrace-cloud login --open
ctrace-cloud whoami
ctrace-cloud tools
```

If you belong to several organisations, select one with `--org YOUR_ORG` or `CORETRACE_ORG`:

```sh
ctrace-cloud --org YOUR_ORG tools
```

From your project directory, preview the upload, then request an analysis with an explicit quote confirmation:

```sh
ctrace-cloud plan --path .
ctrace-cloud run --tools ctrace --path . --confirm
```

Use a tool ID returned by `tools`. The `run` command uploads the project before the estimate is confirmed. **Without `--confirm`, a run auto-confirms and can consume CTU.** `plan` and `run --dry-run` upload nothing, but still authenticate and contact the platform for limits.

For a guided terminal interface, run `ctrace-cloud` with no arguments, or `ctrace-cloud ui`.

## Reports and CI

Export a SARIF report and return exit code 1 when findings reach warning level:

```sh
ctrace-cloud run --tools ctrace --path . --yes \
  --format sarif --output coretrace.sarif --fail-on warning
```

For CI, set `CORETRACE_TOKEN` to an organisation API key (`ctk_…`) through your CI secret store, and set `CORETRACE_ORG` if needed. The environment key takes precedence over a stored login and is not saved by the client.

Progress and diagnostics go to stderr; report documents go to stdout or `--output`. A successful submission with `--no-wait` does not mean the analysis has succeeded.

| Exit code | Meaning |
| --- | --- |
| 0 | Successful command, or no findings meeting the threshold |
| 1 | Findings at or above `--fail-on` |
| 2 | Invalid configuration, refused input/request or confirmation declined |
| 3 | Authentication failure |
| 4 | Infrastructure/analysis failure, interruption or report integrity failure |
| 5 | Timeout |
| 6 | Job stopped at the CTU cap; report is truncated |

See the [flag reference](docs/cli.md) for all commands, threshold semantics, exclusions, configuration and examples.

## What gets uploaded

The client builds a compressed archive of the selected project directory and uploads it for cloud analysis. It applies `.gitignore`, root `.coretraceignore` and repeatable `--exclude` patterns, plus mandatory exclusions for common credentials, private keys, environment files, dependency directories and version-control metadata. Links escaping the project and unsupported filesystem entries are refused.

Inspect the submission with `ctrace-cloud plan --path .` and use `.coretraceignore` for project-specific exclusions. The [reference](docs/cli.md#upload-selection-and-credentials) explains the selection and credential behavior.

## Upgrade, remove and troubleshoot

- **Upgrade:** rerun your platform's installer. Remove a version pin to select the latest release. `ctrace-cloud update` also exists; see its [access requirements](docs/cli.md#update-and-version).
- **Remove:** delete the executable from its install directory. Run `ctrace-cloud logout` first if you also want to remove the stored sign-in credential. Installation and sign-in state are separate.
- **Command not found:** check that the install directory is on `PATH`; open a new terminal on Windows.
- **Wrong architecture / executable format:** choose the matching asset in the platform table.
- **Authentication or organisation selection:** use `login`, `whoami` and `--org`.
- **Tool refused:** check `tools` for the exact ID and entitlement.
- **Full help:** `ctrace-cloud --help` and `ctrace-cloud run --help`.
