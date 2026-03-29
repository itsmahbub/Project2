# zchunk CodeQL Workflow

## Upstream Notes

Current upstream `README.md` and `meson.build` indicate:

- default branch is `main`
- build system is Meson + Ninja
- important native dependencies include `libzstd`, `libcurl`, and `openssl`
- on macOS, `argp-standalone` may also be needed

I did not find a root `SECURITY.md` file through the GitHub contents API, so responsible disclosure may need to go through issues, maintainer email, or commit history later after we have a confirmed bug.

## Recommended Local Layout

Clone the target inside this project so all artifacts stay together:

```bash
mkdir -p targets
git clone https://github.com/zchunk/zchunk.git targets/zchunk
```

## Install Build Dependencies

This machine currently does not have `meson`, `ninja`, or `pkg-config`.

Run:

```bash
brew install meson ninja pkg-config openssl@3 curl zstd argp-standalone
```

## Build Sanity Check

Run from the project root:

```bash
rm -rf targets/zchunk/build
meson setup targets/zchunk/build targets/zchunk
ninja -C targets/zchunk/build
```

If Meson cannot find Homebrew libraries on macOS, retry with:

```bash
rm -rf targets/zchunk/build
PKG_CONFIG_PATH="$(brew --prefix openssl@3)/lib/pkgconfig:$(brew --prefix curl)/lib/pkgconfig:$(brew --prefix zstd)/lib/pkgconfig:$(brew --prefix argp-standalone)/lib/pkgconfig" \
meson setup targets/zchunk/build targets/zchunk
ninja -C targets/zchunk/build
```

## Current Local Blocker

With CodeQL `2.23.9` on this Apple Silicon machine, we observed three distinct problems:

1. Manual traced build:
   linker requested `x86_64` while Homebrew libraries were `arm64`
2. Compile-command replay:
   extractor reported an LMDB `existencedb` open failure
3. `build-mode none`:
   extractor started, generated commands, then stalled locally

We upgraded CodeQL to `2.25.1` and retried. The local macOS run still stalled after only a few extracted compilations, without producing a final SARIF result.

Conclusion:

- use Linux for the CodeQL phase of this project
- use this Mac for normal builds, repro, and AFL work

## Successful Linux Run

The traced-build workflow completed successfully on an Ubuntu `x86_64` EC2 host with CodeQL `2.25.1`.

Command used on Linux:

```bash
./scripts/run-codeql-zchunk-linux.sh
```

Output locations from the successful run:

- database: `codeql/databases/zchunk-linux-cpp`
- SARIF results: `codeql/results/zchunk-linux-cpp.sarif`

The SARIF file has also been copied back into this local project directory for analysis.

## First Triage Summary

Raw result count from the successful Linux run: `40`

Most of those findings are low-risk hygiene issues or warnings in `test/` programs. The real application-code findings worth checking further are:

- `src/unzck.c:153` - `cpp/bad-strncpy-size`
- `src/unzck.c:165` - `cpp/world-writable-file-creation`
- `src/zck.c:227` - `cpp/world-writable-file-creation`
- `src/zck_dl.c:352` - `cpp/world-writable-file-creation`
- `src/zck_gen_zdict.c:276` - `cpp/world-writable-file-creation`

Initial judgment:

- `src/unzck.c:153` is the best memory-safety-adjacent lead from CodeQL, but it is not yet a confirmed bug because `out_name` is allocated with `calloc`, so the destination is already NUL-padded before `strncpy`.
- The `0666` file creation sites are probably lower-priority unless they can be shown to create a realistic local privilege or symlink issue in practice.
- The `path-injection`, `unbounded-write`, and `uncontrolled-process-operation` findings are all in test utilities, so they are not good candidates for the project vulnerability unless a similar pattern exists in production code.

## Next Step After Analysis

Review the SARIF results and prioritize:

- buffer handling
- integer-overflow-to-allocation patterns
- unchecked lengths from file metadata
- memcpy or memmove paths in parser code
- decompression or dictionary handling paths

## Sources

- [zchunk README](https://github.com/zchunk/zchunk/blob/main/README.md)
- [zchunk meson.build](https://github.com/zchunk/zchunk/blob/main/meson.build)
