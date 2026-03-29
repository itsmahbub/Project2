# CodeQL Local Setup

## Recommendation

Use a project-local install under `tools/` instead of a Python virtual environment.

Why:

- CodeQL is not a Python package
- Python `venv` does not isolate compilers or CodeQL extractors
- a repo-local `tools/codeql/` directory keeps this project self-contained anyway

You may still use Conda later for helper Python scripts, but it is not needed for CodeQL itself.

## Recommended Version

Prefer the latest CodeQL bundle available from GitHub releases.

Why this matters:

- this project first used CodeQL `2.23.9`
- on Apple Silicon macOS, that version hit multiple C/C++ extraction issues for `zchunk`
- after upgrading to `2.25.1`, the local C/C++ extractor still stalled on `zchunk`
- newer bundles are still worth trying on future machines, but this specific machine should not be our primary CodeQL host

## Prerequisites

Already confirmed on this machine:

- Apple command line tools are present
- Java is installed
- `zstd`, `tar`, and `unzip` are present

On Apple Silicon, GitHub's setup docs say to ensure Rosetta 2 is installed.

## Install Steps

Run these commands from the project root:

```bash
mkdir -p tools
softwareupdate --install-rosetta --agree-to-license
curl -L -o /tmp/codeql-bundle-osx64.tar.zst https://github.com/github/codeql-action/releases/download/codeql-bundle-v2.25.1/codeql-bundle-osx64.tar.zst
rm -rf tools/codeql
tar --use-compress-program=unzstd -xf /tmp/codeql-bundle-osx64.tar.zst -C tools
mv tools/codeql tools/codeql-bundle-v2.25.1 2>/dev/null || true
mv tools/codeql-bundle-v2.25.1 tools/codeql 2>/dev/null || true
./tools/codeql/codeql version
```

If the extracted directory is already `tools/codeql`, the `mv` lines are harmless.

## Verify

These should succeed:

```bash
./tools/codeql/codeql version
./scripts/codeql-env.sh
```

## First Analysis Workflow

After cloning a target repo into this project, the general flow is:

```bash
./scripts/run-codeql-cpp-none.sh /absolute/path/to/target-repo
```

That script will:

- create a C/C++ database under `codeql/databases/`
- run the standard C/C++ security-and-quality suite
- save SARIF results under `codeql/results/`

If you later want the higher-precision traced-build mode, use:

```bash
./scripts/run-codeql-cpp.sh /absolute/path/to/target-repo "real build command"
```

## Notes

- Current GitHub docs say C/C++ also supports `--build-mode=none`, which creates a database directly from source without running a build.
- `build-mode none` is a good default for local triage.
- Manual build tracing can still be more precise when it works reliably.

## Current Apple Silicon Status In This Project

Observed on macOS arm64 with CodeQL `2.23.9`:

- traced native build hit an `x86_64` versus `arm64` linker mismatch
- compile-command replay avoided the link step, but the extractor hit an LMDB `existencedb` error
- `build-mode none` started correctly but stalled locally, even with `--threads=1`

Practical takeaway:

- the latest bundle was tested here and did not fully fix local C/C++ extraction for `zchunk`
- run CodeQL for C/C++ on Linux for this project
- keep local macOS builds for normal development and fuzzing

## Sources

- GitHub setup guide: <https://docs.github.com/en/code-security/how-tos/scan-code-for-vulnerabilities/scan-from-the-command-line/setting-up-the-codeql-cli>
- GitHub CodeQL CLI manual: <https://docs.github.com/en/code-security/reference/code-scanning/codeql/codeql-cli-manual/database-create>
- CodeQL system requirements: <https://codeql.github.com/docs/codeql-overview/system-requirements/>
- Current CodeQL bundle release: <https://github.com/github/codeql-action/releases>
