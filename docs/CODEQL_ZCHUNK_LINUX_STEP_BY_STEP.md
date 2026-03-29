# Step-by-Step: Run CodeQL on zchunk in Linux

## Who This Is For

This guide is for a beginner who wants to:

- install CodeQL on Linux
- scan the `zchunk` target
- save the results in this project
- do a first-pass interpretation of the findings

The commands below were tested with Ubuntu on an AWS EC2 machine.

## What You Will Have At The End

If everything works, you will end up with:

- a local copy of the `zchunk` source code in `targets/zchunk`
- a CodeQL database in `codeql/databases/zchunk-linux-cpp`
- a SARIF results file in `codeql/results/zchunk-linux-cpp.sarif`

That SARIF file is the main output you will inspect.

## Before You Start

You should have:

- a Linux machine, VM, or EC2 instance
- enough free disk space
  A safe target is at least `10 GB` free
- this `Project2` directory available on the Linux machine

Check free space:

```bash
df -h
```

## Step 1: Go To The Project Directory

Open a terminal and move into the project:

```bash
cd ~/Project2
```

If your project is stored somewhere else, use that path instead.

## Step 2: Install Linux Dependencies

Run:

```bash
sudo apt update
sudo apt install -y build-essential git curl zstd unzip python3 jq ripgrep pkg-config meson ninja-build libssl-dev libcurl4-openssl-dev libzstd-dev libargp-standalone-dev
```

What these are for:

- `build-essential`: C compiler and build tools
- `meson` and `ninja-build`: needed to build `zchunk`
- `jq`: helps inspect JSON and SARIF results
- `ripgrep`: helps search results quickly
- `libssl-dev`, `libcurl4-openssl-dev`, `libzstd-dev`: libraries required by `zchunk`

If `libargp-standalone-dev` is not available on your Linux distribution, try the rest of the command without it.

## Step 3: Install the CodeQL CLI

Create the local tools directory:

```bash
mkdir -p tools
```

Download the Linux CodeQL bundle:

```bash
curl -L -o /tmp/codeql-bundle-linux64.tar.zst https://github.com/github/codeql-action/releases/download/codeql-bundle-v2.25.1/codeql-bundle-linux64.tar.zst
```

Remove any old local CodeQL copy:

```bash
rm -rf tools/codeql
```

Extract the bundle:

```bash
tar --use-compress-program=unzstd -xf /tmp/codeql-bundle-linux64.tar.zst -C tools
mv tools/codeql-bundle-v2.25.1 tools/codeql 2>/dev/null || true
```

Verify the install:

```bash
./tools/codeql/codeql version
```

Expected result:

```text
CodeQL command-line toolchain release 2.25.1
```

If you see a version line, the install worked.

## Step 4: Get The zchunk Source Code

If `targets/zchunk` does not already exist, clone it:

```bash
mkdir -p targets
git clone https://github.com/zchunk/zchunk.git targets/zchunk
```

Check that the directory exists:

```bash
ls targets/zchunk
```

## Step 5: Run The Main CodeQL Scan

Use the Linux traced-build workflow:

```bash
./scripts/run-codeql-zchunk-linux.sh
```

What this script does:

1. checks that `targets/zchunk` exists
2. builds `zchunk` with Meson and Ninja
3. lets CodeQL observe the build
4. creates a CodeQL database
5. runs the default C/C++ security-and-quality queries
6. saves results as SARIF

This step can take a while.

## Step 6: Confirm That The Scan Worked

Check for the expected output files:

```bash
ls codeql/databases/zchunk-linux-cpp
ls codeql/results/zchunk-linux-cpp.sarif
```

If both exist, the scan completed successfully.

You can also check the file size:

```bash
wc -c codeql/results/zchunk-linux-cpp.sarif
```

If the SARIF file is non-empty, that is a good sign.

## Step 7: If The Main Scan Fails

If the traced-build workflow fails, try the fallback workflow:

```bash
./scripts/run-codeql-zchunk-linux-none.sh
```

This uses CodeQL's `build-mode none` support for C/C++.

Fallback output locations:

- `codeql/databases/zchunk-linux-none-cpp`
- `codeql/results/zchunk-linux-none-cpp.sarif`

Use the traced-build workflow first whenever possible. It is the preferred path for this project.

## Step 8: Count The Findings

To see how many results you got:

```bash
jq '[.runs[].results[]] | length' codeql/results/zchunk-linux-cpp.sarif
```

To count how many findings belong to each rule:

```bash
jq -r '.runs[].results[] | .ruleId' codeql/results/zchunk-linux-cpp.sarif | sort | uniq -c | sort -nr
```

This is useful because some CodeQL results are just style or cleanup suggestions, while others are much more security-relevant.

## Step 9: Print A Simple Results Table

Run:

```bash
jq -r '.runs[].results[] | [.ruleId, .locations[0].physicalLocation.artifactLocation.uri, (.locations[0].physicalLocation.region.startLine|tostring), (.message.text // .message.markdown // "")] | @tsv' codeql/results/zchunk-linux-cpp.sarif
```

This prints four columns:

- rule id
- file path
- line number
- short message

This is one of the easiest ways for a beginner to read SARIF without needing a special viewer.

## Step 10: Focus On Production Code, Not Test Code

Many CodeQL results are not useful for vulnerability research if they are only in test files.

To hide results from `test/`:

```bash
jq -r '.runs[].results[] | [.ruleId, .locations[0].physicalLocation.artifactLocation.uri, (.locations[0].physicalLocation.region.startLine|tostring), (.message.text // .message.markdown // "")] | @tsv' codeql/results/zchunk-linux-cpp.sarif | rg -v $'\ttest/'
```

This is an important triage step.

For this project, many findings appeared in `test/` code and were not good vulnerability candidates.

## Step 11: What To Look For First

For this class project, prioritize findings related to:

- buffer overflows
- bad length checks
- dangerous string copies
- integer overflow before allocation
- file-format parsing mistakes
- decompression or dictionary parsing

Examples of promising patterns:

- `strcpy`, `strncpy`, `memcpy`, `memmove`
- arithmetic using attacker-controlled sizes or offsets
- reading lengths from a file and using them in allocation or copy operations
- loops that trust on-disk metadata too early

Less exciting patterns:

- style warnings
- documentation warnings
- issues only in test programs
- redundant `free(NULL)` checks

## Step 12: Open The Source At A Reported Line

If CodeQL reports a finding at line 153 in `src/unzck.c`, inspect it like this:

```bash
nl -ba targets/zchunk/src/unzck.c | sed -n '145,160p'
```

Why this matters:

- CodeQL gives you a lead
- you still need to read the code yourself
- a warning is not automatically a real vulnerability

## Step 13: Decide Whether A Finding Is Real

Ask these questions:

1. Is the code in the real application, or only in tests?
2. Can outside input reach this code?
3. Could a malicious file or argument influence the length, size, offset, or destination buffer?
4. Is there a real overflow, out-of-bounds access, or dangerous file operation?
5. Can you explain the bug clearly enough to reproduce and fix it?

If the answer is mostly "no", the result may be a false positive or low-priority issue.

## Step 14: Example From This Project

The Linux CodeQL scan on `zchunk` produced one notable string-handling lead in:

- `src/unzck.c:153`

CodeQL flagged:

- `cpp/bad-strncpy-size`

But after manual inspection, it did not immediately look like a real overflow because:

- the destination buffer was allocated with `calloc`
- the code copied exactly `strlen(base_name)` bytes
- the destination remained NUL-padded

That means:

- the finding is worth reviewing
- but it is not enough on its own to claim a vulnerability

This is a normal outcome in static analysis.

## Step 15: Save Your Notes

As you triage findings, keep a short record in the project docs:

- what CodeQL reported
- where it was reported
- whether it is in production code or test code
- whether it looks real, unclear, or likely false positive
- what should be fuzzed next

The current project already has related notes in:

- [CODEQL_LINUX.md](CODEQL_LINUX.md)
- [ZCHUNK_CODEQL.md](ZCHUNK_CODEQL.md)

## Troubleshooting

### Problem: `codeql` command does not work

Run:

```bash
./tools/codeql/codeql version
```

If that fails, the bundle may not be extracted correctly.

### Problem: Not enough disk space

Check:

```bash
df -h
```

If space is low, clean old databases and results:

```bash
rm -rf codeql/databases/*
rm -rf codeql/results/*
```

### Problem: `targets/zchunk` is missing

Clone it:

```bash
mkdir -p targets
git clone https://github.com/zchunk/zchunk.git targets/zchunk
```

### Problem: The traced-build scan fails

Use the fallback:

```bash
./scripts/run-codeql-zchunk-linux-none.sh
```

## Summary

The beginner workflow is:

1. install Linux dependencies
2. install CodeQL locally in `tools/codeql`
3. clone `zchunk` into `targets/zchunk`
4. run `./scripts/run-codeql-zchunk-linux.sh`
5. inspect `codeql/results/zchunk-linux-cpp.sarif`
6. filter out test-code noise
7. manually review the strongest production-code findings

That gets you from zero setup to a real CodeQL triage workflow for this project.
