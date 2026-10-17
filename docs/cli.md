# ctrace-cloud command and flag reference

This reference describes **v0.3.0**. Check your installed version with `ctrace-cloud version`; use `ctrace-cloud --help` or `ctrace-cloud <command> --help` for the options shipped by your binary.

For installation instructions, platform assets and checksum/signature verification, see the [README](../README.md).

## Contents

- [Command overview](#command-overview)
- [Global flags](#global-flags)
- [run](#run)
- [Finding thresholds](#finding-thresholds)
- [report](#report)
- [plan](#plan)
- [jobs](#jobs)
- [tools and whoami](#tools-and-whoami)
- [login and logout](#login-and-logout)
- [remember](#remember)
- [ui](#ui)
- [cancel](#cancel)
- [update and version](#update-and-version)
- [Project configuration](#project-configuration)
- [Environment variables](#environment-variables)
- [Upload selection and credentials](#upload-selection-and-credentials)
- [Exit codes and output](#exit-codes-and-output)

## Command overview

```text
ctrace-cloud [global options] <command> [command options]
```

| Command | Purpose |
| --- | --- |
| `run` | Package and upload a project, submit analysis, wait and render results. |
| `report <job-id>` | Retrieve reports or logs from a finished job. |
| `plan` | Inspect upload selection and limits without uploading. |
| `jobs` | List recent jobs for the selected organisation. |
| `tools` | List tool IDs, versions, languages and entitlement. |
| `login` | Sign in through a browser device-code flow. |
| `logout` | Remove the stored refresh credential and attempt session revocation. |
| `whoami` | Show identity, organisations and credential source. |
| `remember` | Save tool selection in the project's `.coretrace.yml`. |
| `ui` | Open the interactive terminal session. |
| `cancel <job-id>` | Request cancellation of a job. |
| `version` | Show version, commit and platform; optionally check for updates. |
| `update` | Explicitly download, verify and replace the installed binary. |
| `help [command]` | Show general or command-specific help. |

Run `ctrace-cloud` without arguments to open the interactive session when stdin/stdout are terminals, `CI` is unset and `TERM` is not `dumb`. Otherwise it prints help.

## Global flags

Place global flags before the command in scripts for clarity.

| Flag | Default / environment | Behavior |
| --- | --- | --- |
| `-h, --help` | None | Print help and exit successfully. Available on each command as well. |
| `-V` | None | Print the client version and exit. Use the `version` command for build details. |
| `--base-url <url>` | `CORETRACE_BASE_URL`, otherwise `https://api.coretrace.fr` | Select the platform API address. A trailing `/v1` is normalized away. HTTPS is required unless local development HTTP is explicitly enabled. Embedded credentials, query strings and fragments are rejected. |
| `--org <slug>` | `CORETRACE_ORG`, otherwise the single membership | Select the organisation by slug or ID. Required when membership is ambiguous. |
| `--profile <name>` | `CORETRACE_PROFILE`, otherwise the platform URL's host | Select the credential-store profile. Useful for separate accounts or deployments; it does not change the platform address. |
| `--ca-file <pem>` | `CORETRACE_CA_FILE`, otherwise system roots | Supply a private certificate-authority PEM file for platform connections. |
| `--no-color` | Color depends on the terminal and `NO_COLOR` | Disable colored output. Does not select a report format. |
| `--json-errors` | Off | Render caught operational errors as JSON on stderr, with `code`, `message` and optional `detail`. Does not turn reports or all diagnostics into JSON; argument-parser errors still use parser text in v0.3.0. |
| `-v, --verbose` | `CORETRACE_LOG`, otherwise `info` | Enable debug logging on stderr, including stack details for caught errors. Lowercase `-v` is verbose; uppercase `-V` is version. |

Explicit global flags override the corresponding environment settings, which override built-in defaults.

```sh
ctrace-cloud --org my-team --no-color tools
ctrace-cloud --profile staging --base-url https://api.staging.example.com whoami
ctrace-cloud --json-errors run --tools ctrace --path .
```

## run

```sh
ctrace-cloud run --tools ctrace --path . --confirm
```

The normal flow is authentication and organisation selection → limits and tool checks → packaging → upload and upload verification → job creation → quote → optional confirmation → wait → reports.

**Default behavior auto-confirms.** Add `--confirm` to request an explicit decision before CTU is reserved. This decision happens after source upload. Use `plan` or `--dry-run` to inspect selection before uploading.

| Flag | Default | Behavior |
| --- | --- | --- |
| `--tools <list>` | `tools:` from `.coretrace.yml` | Comma-separated tool IDs, e.g. `ctrace,stack-analyzer`. Whitespace is trimmed. At least one is required for `run`, including dry runs. Discover IDs with `tools`. |
| `--path <dir>` | `.` | Project directory to package, resolved from the current working directory. The CLI reads `.coretrace.yml` at this root. |
| `--no-wait` | Wait enabled | Submit the job, print its ID to stdout and return 0 without waiting for final analysis results. Use `jobs` to check status, then `report` once finished. Format/output/threshold do not produce a final report in this mode. Explicit quote confirmation, if requested, still happens before returning. |
| `--format <fmt>` | `pretty` | Report format: `pretty`, `json`, `sarif` or `gitlab-codequality`. Progress remains on stderr. |
| `--output <file>` | stdout | Write the completed report document to this file, relative to the current working directory. Create parent directories beforehand. The file is overwritten. |
| `--allow-partial` | Off | Allow the entitled tool subset to run when some requested tools are not entitled. Unknown tool IDs still fail, and an empty accepted selection fails. Rejected tools are reported. |
| `--confirm` | Off | Create an estimate job, display its quote and ask for approval. Requires an interactive terminal with `pretty` output. Declining cancels the job and returns 2; an expired confirmation returns 5. |
| `--yes` | Off as a flag; runs otherwise auto-confirm | Suppress explicit confirmation, including when combined with `--confirm`. Use for unattended runs. Does not override entitlement, upload limits or platform policy. |
| `--fail-on <level>` | Project `fail_on:`, otherwise `any` | Choose which finding levels make the final exit code 1. Values: `any`, `error`, `warning`, `note`, `none`. Does not filter findings out of the report. |
| `--idempotency-key <key>` | Generated from input ID, accepted tools and tool configuration | Supply the job-creation deduplication key for the normal auto-confirm path. Use the same key only for the same intended request. It does not skip packing/upload; v0.3.0 does not apply it to the separate estimate-job path used by `--confirm`. |
| `--config <file>` | Project `config:`, otherwise unset | Load tool configuration from a JSON or YAML mapping. The path is relative to the current working directory, not `--path`. Replaces the project's `config:` mapping rather than merging it. This is tool configuration, not a client login/platform settings file. |
| `--timeout <duration>` | `30m` | Maximum job-wait duration. Accepts nonnegative integers with `ms`, `s`, `m` or `h`, e.g. `500ms`, `30s`, `10m`, `1h`; bare integers mean seconds. This is not a whole-command deadline. Packaging/upload and confirmation have separate behavior; the estimate wait is limited to the smaller of this value and 2 minutes. |
| `--cancel-on-interrupt` | Off | Best-effort remote cancellation when Ctrl+C aborts the normal job-wait phase. Otherwise the client stops waiting and the remote job can continue. This does not turn a timeout into cancellation or guarantee cancellation during earlier phases. |
| `--exclude <pattern>` | No additional patterns | Add a gitignore-style exclusion. Repeat for multiple patterns; quote globs so the shell does not expand them. Mandatory exclusions remain in force. |
| `--dry-run` | Off | Print the upload plan as human-readable text, without packaging/uploading a submission or creating an analysis job. Still needs authentication and contacts the platform for limits. Returns 2 for refused entries or a cap breach. Use `plan --format json` for a structured preview; run's dry-run output remains text. |
| `--gitlab-job-token` | Off | Exchange `CI_JOB_TOKEN` and `CI_SERVER_HOST` for a short-lived platform credential. Both variables are required and the platform integration must permit the exchange. An explicit `CORETRACE_TOKEN` takes precedence. |

### Examples

Preview extra exclusions:

```sh
ctrace-cloud run --tools ctrace --path . --dry-run \
  --exclude 'generated/**' --exclude 'fixtures/**'
```

Submit from CI with a token supplied through the CI secret store:

```sh
ctrace-cloud run --tools ctrace --path . --yes \
  --format sarif --output coretrace.sarif --fail-on warning --timeout 45m
```

Submit without waiting:

```sh
ctrace-cloud run --tools ctrace --path . --yes --no-wait
ctrace-cloud jobs --limit 10
ctrace-cloud report JOB_ID --format json --output report.json
```

Replace `JOB_ID` with the full UUID printed by the submission. A no-wait exit code is a submission outcome, not a CI findings verdict.

## Finding thresholds

The threshold affects the final exit code of `run` and `report`; all findings remain in exported reports.

| `--fail-on` | Findings that produce exit code 1 |
| --- | --- |
| `any` | Any finding; default |
| `error` | Error |
| `warning` | Warning or error |
| `note` | Note, warning or error |
| `none` | None; findings alone do not fail the command |

`none` does not suppress authentication, configuration, infrastructure, timeout or CTU-cap failures. A truncated report still returns 6.

## report

```sh
ctrace-cloud report JOB_ID --format sarif --output coretrace.sarif
```

Downloads the reports of a finished job without submitting code again. The job ID is a full UUID. An unfinished job returns 2; this command does not wait.

| Flag | Default | Behavior |
| --- | --- | --- |
| `--format <fmt>` | `pretty` | `pretty`, `json`, `sarif` or `gitlab-codequality`. |
| `--output <file>` | stdout | Write the report to a file, overwriting it. Path is relative to the current directory. |
| `--fail-on <level>` | `any` | Apply the finding threshold to this retrieval. Does not inherit `fail_on:` from a local project or reuse the earlier run's CLI threshold. |
| `--log` | Off | Print available tool logs to stdout instead of a finding report. Missing logs are noted on stderr. In this mode `--output` is not used and findings do not determine the exit code; redirect stdout if you want a log file. |

```sh
ctrace-cloud report JOB_ID --log > tool-logs.txt
ctrace-cloud report JOB_ID --fail-on none --format json --output report.json
```

## plan

```sh
ctrace-cloud plan --path . --exclude 'generated/**' --format json
```

Shows the submission root, selected file count/size, exclusion summaries, refusals and limit breaches without uploading code or creating an analysis job. It still authenticates and fetches organisation limits. This previews file selection, not a CTU price quote.

| Flag | Default | Behavior |
| --- | --- | --- |
| `--path <dir>` | `.` | Project directory to inspect. |
| `--tools <list>` | Project `tools:`, otherwise empty | Comma-separated tool IDs to display with the plan. Optional; this preview does not validate tool entitlement. |
| `--exclude <pattern>` | None | Repeatable gitignore-style exclusions. |
| `--format <fmt>` | `pretty` | `pretty` text or `json`. JSON includes `upload_blocked`, `refusals` and `cap_breach`. |

Returns 0 for an allowed plan and 2 for refusals or a cap breach. `run --dry-run` uses the same selection logic, but requires tool selection and prints text.

## jobs

```sh
ctrace-cloud jobs --limit 20 --status completed --format json
```

Lists recent jobs for the selected organisation.

| Flag | Default | Behavior |
| --- | --- | --- |
| `--limit <n>` | `50` | Number of recent jobs to request; integer from 1 through 500. |
| `--status <status>` | No filter | Pass a job-status filter to the platform, e.g. `completed`. This filters execution status, not finding severity or job conclusion. |
| `--format <fmt>` | `pretty` | Human-readable table or `json`. |

The table shows creation time, abbreviated ID, source, tools, status, conclusion, billed CTU and rejection reason. Use JSON when you need full job IDs for scripts.

## tools and whoami

```sh
ctrace-cloud tools --format json
ctrace-cloud whoami --format json
```

Both commands accept `--format <fmt>`, default `pretty`, with `json` for structured output.

- `tools`: tool IDs, versions, languages and entitlement for the selected organisation.
- `whoami`: client version, platform address, principal, organisations, selected organisation and credential source. If membership is ambiguous, it can show memberships without selecting one.

## login and logout

```sh
ctrace-cloud login --open
ctrace-cloud logout
```

| Command / flag | Default | Behavior |
| --- | --- | --- |
| `login --open` | Off | Attempt to open the device-code verification address in the default browser. The address and code are still printed. |
| `login --no-store` | Credential storage enabled | Complete sign-in without saving the refresh credential. Since the login process then exits, this does not authenticate later commands. |
| `logout` | No command-specific flags | Remove the stored credential for the selected profile and attempt to revoke its session at the platform. Does not unset an environment API key. |

`CORETRACE_TOKEN` takes precedence over stored sign-in. Logging in while it is set does not change the credential used by later commands until the variable is removed.

## remember

```sh
ctrace-cloud remember --path . --tools ctrace,stack-analyzer
ctrace-cloud run --path . --confirm
```

| Flag | Default | Behavior |
| --- | --- | --- |
| `--path <dir>` | `.` | Directory containing the project's `.coretrace.yml`. |
| `--tools <list>` | Required | Save comma-separated tool IDs under `tools:`, preserving other keys/comments. Creates the file if absent. |

Checks IDs against the catalogue when authenticated. Without a credential, writes them with a notice that IDs were not checked. This changes a local project file and does not submit a job.

## ui

```sh
ctrace-cloud ui --path . --tools ctrace
```

| Flag | Default | Behavior |
| --- | --- | --- |
| `--path <dir>` | No explicit preselection | Preselect a project directory in the interactive session. |
| `--tools <list>` | No explicit preselection | Preselect comma-separated tools. |

Requires terminal stdin/stdout and `TERM` other than `dumb`; otherwise returns 2. Unlike the no-argument entry point, explicit `ui` ignores `CI`. The full interface needs at least 80×24 terminal cells.

The session includes sign-in, organisation/project/tool selection, quote confirmation, live progress, findings and history. Use arrows/Enter to select, Escape to go back, `q` to quit and `?` for key help. The interactive flow explicitly confirms its estimate.

## cancel

```sh
ctrace-cloud cancel JOB_ID
```

Requires a full job UUID and has no command-specific flags. Requests cancellation and prints the resulting status/conclusion and billed CTU. An already terminal job returns 2. Cancellation does not imply that previously consumed CTU is refunded.

## update and version

```sh
ctrace-cloud version
ctrace-cloud version --check
ctrace-cloud update
```

| Command / flag | Default | Behavior |
| --- | --- | --- |
| `version` | No command-specific flags required | Print version, commit and platform information. |
| `version --check` | Off | Request an update check and print a notice when a newer release is found. Does not install it. |
| `update` | No command-specific flags | Fetch the platform-advertised release, verify its signed manifest, SLSA provenance, binary checksum and signature, then replace the installed binary. Windows completes replacement after process exit. |

Self-update downloads pinned `cosign` and `slsa-verifier` binaries into a temporary directory and checks their embedded SHA-256 values before using them. It needs access to those upstream GitHub releases as well as the advertised client release. It refuses development runtimes, symlinks and unsafe installation layouts.

In v0.3.0, self-update can need `CORETRACE_RELEASE_TOKEN` to access releases in the private source repository. This is a GitHub read credential, separate from `CORETRACE_TOKEN`; a platform API key cannot replace it. Public downloads from this repository's installers do not need a GitHub token.

For a public-download upgrade, rerun the platform installer described in the [README](../README.md). To downgrade or pin a version, use `CORETRACE_VERSION` with the installer; `update` has no version-selection flag.

The periodic update notice is informational and never replaces the binary automatically.

## Project configuration

`run` reads `.coretrace.yml` directly in the directory selected by `--path`. It does not search parent directories.

```yaml
tools:
  - ctrace
fail_on: warning
config: {}
```

- `tools:` is a list of tool IDs.
- `fail_on:` accepts the same levels as `--fail-on`.
- `config:` is a mapping of platform/tool-specific configuration. Its contents depend on the selected tools; the client does not invent a generic analyzer flag schema.
- Explicit `--tools`, `--fail-on` and `--config` override their project values. A configuration file supplied by `--config` replaces the entire `config:` mapping.
- Integration-only keys such as `summary_comment` are ignored by the CLI.
- `report` does not read project configuration.

## Environment variables

### Client and authentication

| Variable | Default | Effect |
| --- | --- | --- |
| `CORETRACE_BASE_URL` | `https://api.coretrace.fr` | Platform API address; overridden by `--base-url`. |
| `CORETRACE_ORG` | Single membership | Organisation slug or ID; overridden by `--org`. |
| `CORETRACE_PROFILE` | Platform URL host | Credential profile; overridden by `--profile`. |
| `CORETRACE_TOKEN` | Unset | Organisation API key beginning `ctk_`; overrides other credential sources and is never persisted. Set through your secret store. |
| `CORETRACE_CA_FILE` | System roots | Private CA PEM path; overridden by `--ca-file`. |
| `CORETRACE_LOG` | `info` | `debug`, `info`, `warn`, `error` or `silent`; `--verbose` selects debug. |
| `NO_COLOR` | Unset | Disable terminal colors. |
| `CORETRACE_CONFIG_DIR` | Windows: `%APPDATA%\CoreTrace`; elsewhere: `$XDG_CONFIG_HOME/coretrace` or `~/.config/coretrace` | Override the credential/state directory. |
| `CORETRACE_CREDENTIAL_STORE` | `auto` | `auto`, `keychain` or `file`. Auto prefers the OS credential store, with encrypted-file fallback. |
| `CORETRACE_CREDENTIAL_KEY` | Locally generated key file | Encryption key override for the file credential store: 64 hexadecimal characters (32 bytes). Keep it secret. |
| `CORETRACE_TMPDIR` | OS temporary directory | Directory used for the temporary upload archive. |
| `CORETRACE_NO_UPDATE_CHECK` | Unset | Set to `1` to suppress periodic update notices. |
| `CORETRACE_RELEASE_TOKEN` | Unset | GitHub read token for self-update when the advertised release is private. |
| `CORETRACE_DEV_INSECURE` | Unset | Set to `1` to permit HTTP against a local development stack. |
| `CORETRACE_USE_GITLAB_JOB_TOKEN` | Unset | Set to `1` to enable GitLab job-token exchange; `run --gitlab-job-token` enables it for that run. Requires `CI_JOB_TOKEN` and `CI_SERVER_HOST`. |
| `CORETRACE_TELEMETRY` | Unset | Recognized future opt-in setting; has no effect in v0.3.0. No usage telemetry is sent either way. |

For code using the shared client library under Node rather than the compiled binary, supply a private CA with `NODE_EXTRA_CA_CERTS`.

### Interactive session

| Variable | Effect |
| --- | --- |
| `CI` | Prevent automatic interactive entry when set. Explicit `ui` still requires an actual terminal. |
| `TERM` | `dumb` disables the interactive session. |
| `CORETRACE_EDITOR`, `VISUAL`, `EDITOR` | Editor selection, in that order, when opening a finding. |
| `CORETRACE_STALL_SECONDS` | Progress-stall threshold; default 60 seconds. The session offers to cancel or continue waiting. |

Installer-only variables `CORETRACE_VERSION`, `CORETRACE_INSTALL_DIR` and `CORETRACE_DOWNLOAD_URL` are documented in the [README](../README.md#pin-a-version-or-change-the-install-location).

## Upload selection and credentials

The client uploads a `tar.zst` source archive to a platform-provided storage URL. It does not install analysis tools locally.

Selection applies nested `.gitignore` rules, root `.coretraceignore`, then `--exclude` patterns, followed by mandatory exclusions that cannot be negated. Mandatory exclusions cover common version-control metadata, environment files, private keys, credential files, infrastructure state, dependency trees and OS litter. These names do not guarantee that all project-specific sensitive files are excluded; inspect the preview and add your own patterns.

Symlinks outside the root, dangling links, devices, sockets and named pipes are refused. Links to files inside the root become file copies; directory links are skipped and counted.

`plan` and `run --dry-run` show selection summaries and refusal/cap information without uploading code. Both still contact the platform.

Interactive login stores only a refresh credential, preferably in the OS store (macOS Keychain, Linux Secret Service or Windows Credential Manager). With no available OS store, auto mode uses an encrypted file and prints a warning; its protection depends on the user's config-directory permissions. Access tokens remain in process memory. An environment API key is not stored.

## Exit codes and output

| Code | Meaning |
| --- | --- |
| 0 | Successful command; for a completed analysis, no finding meets the selected threshold. With `--no-wait`, submission succeeded and results are not evaluated. |
| 1 | At least one finding meets `--fail-on`. |
| 2 | Invalid arguments/configuration, refused upload entry or limit, unknown/unentitled tool, refused request, declined quote, decision requiring an unavailable terminal, or a report requested before completion. |
| 3 | Missing/refused credentials, revoked session or failed device sign-in. |
| 4 | Platform/network failure, analysis failure, interruption or report digest mismatch. |
| 5 | Job-wait timeout, upload-verification timeout or expired confirmation window. |
| 6 | Platform stopped at the CTU cap; the report is truncated. |

Human or structured reports go to stdout unless `--output` selects a file. Progress, notices and operational errors go to stderr. `report --log` writes logs to stdout. `--json-errors` only changes caught operational errors, not every stderr line.

For a CI gate, wait for completion and inspect the exit code. Selecting `--fail-on none` cannot make an incomplete, failed or capped analysis count as a successful full analysis.
