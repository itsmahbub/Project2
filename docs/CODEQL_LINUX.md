# CodeQL on Linux

## Goal

Use Linux for the CodeQL phase of this project, while keeping macOS for normal local builds and AFL work.

## Recommended Environment

Use one of:

- Ubuntu 24.04 VM
- Ubuntu 22.04 VM
- a remote Linux machine you control

This is the preferred path for `zchunk` because local macOS arm64 extraction was unreliable even after upgrading CodeQL.

## Linux Setup

From the project root on Linux:

```bash
sudo apt update
sudo apt install -y build-essential git curl zstd unzip python3 pkg-config meson ninja-build libssl-dev libcurl4-openssl-dev libzstd-dev libargp-standalone-dev
```

If `libargp-standalone-dev` is unavailable on your distro, try the build first without it. Some Linux environments already provide `argp` through glibc.

## Install CodeQL

Run from the project root:

```bash
mkdir -p tools
curl -L -o /tmp/codeql-bundle-linux64.tar.zst https://github.com/github/codeql-action/releases/download/codeql-bundle-v2.25.1/codeql-bundle-linux64.tar.zst
rm -rf tools/codeql
tar --use-compress-program=unzstd -xf /tmp/codeql-bundle-linux64.tar.zst -C tools
mv tools/codeql-bundle-v2.25.1 tools/codeql 2>/dev/null || true
./tools/codeql/codeql version
```

## Clone Or Reuse The Target

If the repo is not present yet:

```bash
mkdir -p targets
git clone https://github.com/zchunk/zchunk.git targets/zchunk
```

## Recommended Linux Workflow

Use the traced build first on Linux:

```bash
./scripts/run-codeql-zchunk-linux.sh
```

The project scripts are written to run with `bash` on Linux.

This produces:

- database: `codeql/databases/zchunk-linux-cpp`
- SARIF: `codeql/results/zchunk-linux-cpp.sarif`

## Fallback Linux Workflow

If the traced build fails on Linux for any reason, use:

```bash
./scripts/run-codeql-zchunk-linux-none.sh
```

This produces:

- database: `codeql/databases/zchunk-linux-none-cpp`
- SARIF: `codeql/results/zchunk-linux-none-cpp.sarif`

## Reviewing Results

After a successful run:

```bash
rg '"ruleId"|"message"|"security-severity"' codeql/results/zchunk-linux-cpp.sarif
```

For this project, the EC2 traced-build run succeeded and produced:

- `codeql/databases/zchunk-linux-cpp`
- `codeql/results/zchunk-linux-cpp.sarif`

The SARIF file was then copied back into the local project directory for offline triage on macOS.

If you used the fallback mode instead:

```bash
rg '"ruleId"|"message"|"security-severity"' codeql/results/zchunk-linux-none-cpp.sarif
```

## What To Prioritize

- file-format parsing
- length and offset arithmetic
- allocation size calculations
- `memcpy`, `memmove`, `strcpy`, `strncpy`, and related APIs
- decompression and dictionary handling code

## Practical Note

For this project, Linux is the analysis host and macOS is the experimentation host:

- Linux: CodeQL
- macOS: build validation, repro, AFL, PoC minimization
