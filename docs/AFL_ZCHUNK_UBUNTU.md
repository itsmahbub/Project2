# Step-by-Step: Run AFL++ On zchunk In Ubuntu

## Goal

Set up one clear AFL++ workflow for `zchunk` and explain how to fuzz more than one part of the program without rebuilding everything over and over.

This guide is for the first practical fuzzing pass, not a final custom harness.

The workflow below was tested on Ubuntu `24.04` on an AWS EC2 machine.

## The Core Model

The most important point is:

- build `zchunk` once with AFL++ instrumentation
- let that one build produce several instrumented executables
- run AFL++ separately against whichever executable and argument set you want to study

So:

- you do not need a completely different source tree for each target
- you do not need a separate Meson configuration for `unzck` versus `zck_read_header`
- you usually do want separate AFL output directories for separate target commands

This is also why the project documentation mentions several zchunk targets. They are separate AFL target commands, not separate source-code projects.

## Why There Are Multiple zchunk Targets

The upstream `zchunk` build produces multiple command-line utilities from the same source tree. In this project, the AFL++ build instruments that whole build.

Examples include:

- `unzck`
- `zck_read_header`
- `zck`
- `zck_gen_zdict`
- `zck_delta_size`
- `zckdl`

For fuzzing, we care most about the utilities that consume attacker-controlled `.zck` files directly.

## Why Start With `unzck -c @@`

The best first AFL++ target for this project is:

```bash
targets/zchunk/build-afl/src/unzck -c @@
```

Why this is the best baseline:

- it consumes attacker-controlled `.zck` files directly
- it exercises real parser and decompression logic end to end
- the CodeQL triage already pointed us toward `src/unzck.c`
- the upstream repository ships sample `.zck` files under `test/files/` that can seed the corpus

The `-c` flag sends decompressed output to stdout, which avoids creating lots of output files during fuzzing.

## When To Use Alternate Targets

After `unzck`, the next most useful narrow targets are:

1. `zck_read_header -c @@`
2. `zck_read_header -f @@`
3. `zck_read_header @@`

Why these are worth running separately:

- all three enter real `.zck` parsing code
- they are narrower than `unzck`
- they avoid the extra decompression work in the baseline target
- `-c` and `-f` reach slightly different validation and metadata paths

What each one emphasizes:

- `zck_read_header @@`: parses the archive header and prints metadata
- `zck_read_header -c @@`: parses the header and walks chunk information
- `zck_read_header -f @@`: parses the header and validates checksums

## One Build, Many Executables, Many AFL Runs

You can fuzz different parts of the program using different command lines, but do it as separate AFL campaigns.

That means:

- yes, one AFL-instrumented build is enough
- yes, you can run AFL with different command lines for different functionality
- no, you should not try to combine many modes into one single AFL campaign and treat that as the same target

Keeping one fixed target command per AFL run makes the results easier to interpret:

- performance numbers stay comparable
- coverage growth is easier to compare
- crashes are easier to reproduce
- output directories stay cleanly separated

## AFL++ Helper Scripts In This Repo

This project includes:

- `scripts/build-zchunk-afl.sh`
- `scripts/prepare-zchunk-afl-corpus.sh`
- `scripts/run-zchunk-afl.sh`
- `scripts/run-zchunk-afl-pilot.sh`
- `scripts/run-zchunk-afl-target.sh`
- `scripts/run-zchunk-afl-target-pilot.sh`
- `scripts/repro-zchunk-afl-crash.sh`
- `scripts/summarize-zchunk-afl-output.sh`

The first two prepare the build and corpus. The `run-zchunk-afl*.sh` wrappers are for the baseline `unzck -c` target. The `run-zchunk-afl-target*.sh` wrappers are the generic form for alternate executables and arguments.

## Step 1: Install Ubuntu Dependencies

Run:

```bash
sudo apt update
sudo apt install -y build-essential clang llvm lld git python3 pkg-config meson ninja-build afl++ libssl-dev libcurl4-openssl-dev libzstd-dev libargp-standalone-dev
```

On Ubuntu `24.04`, `libargp-standalone-dev` may be unavailable. If that happens, retry without it:

```bash
sudo apt install -y build-essential clang llvm lld git python3 pkg-config meson ninja-build afl++ libssl-dev libcurl4-openssl-dev libzstd-dev
```

## Step 2: Check That AFL++ Installed Correctly

Run:

```bash
command -v afl-fuzz
command -v afl-clang-fast
clang --version | head -n 2
```

If those commands print valid paths and a Clang version, the toolchain is ready.

## Step 3: Clone Or Reuse The Target

From the project root:

```bash
mkdir -p targets
git clone https://github.com/zchunk/zchunk.git targets/zchunk
```

If `targets/zchunk` already exists, reuse it.

## Step 4: Build zchunk With AFL++ Instrumentation

From the project root:

```bash
./scripts/build-zchunk-afl.sh "$PWD/targets/zchunk"
```

What this does:

- removes any old `build-afl` directory
- configures Meson with `CC=afl-clang-fast`
- builds the target with Ninja
- leaves instrumented executables under `targets/zchunk/build-afl/src/`

After the build, look in:

```bash
ls "$PWD/targets/zchunk/build-afl/src"
```

You should see several instrumented utilities, not just `unzck`.

### Optional Sanitizer Mode

For crash discovery, AddressSanitizer is usually worth enabling:

```bash
AFL_USE_ASAN=1 ./scripts/build-zchunk-afl.sh "$PWD/targets/zchunk"
```

When using ASan, keep the AFL++ memory limit disabled:

- the runner scripts already default to `-m none`

## Step 5: Prepare A Starter Corpus

From the project root:

```bash
./scripts/prepare-zchunk-afl-corpus.sh "$PWD/targets/zchunk"
```

This copies the `.zck` samples already shipped by upstream into:

- `fuzzing/zchunk/in`

At the time this guide was written, the seed source was:

- `targets/zchunk/test/files/`

That directory includes both normal-looking and malformed `.zck` samples, which is a good starter set for a pilot run.

At the time of the tested Ubuntu run, this step copied `14` sample files into `fuzzing/zchunk/in`.

## Step 6: Smoke-Test The Baseline Target

Before running AFL++, make sure the instrumented baseline command works with a known-good sample:

```bash
./targets/zchunk/build-afl/src/unzck -c ./fuzzing/zchunk/in/LICENSE.nodict.fodt.zck >/dev/null
echo $?
```

Expected result:

- exit code `0`

If this smoke test fails, fix the build before starting AFL++.

## Step 7: Run A Short Pilot AFL++ Campaign

The easiest beginner command is the pilot wrapper:

```bash
./scripts/run-zchunk-afl-pilot.sh 120
```

This wrapper:

- clears old `fuzzing/zchunk/out` and runtime state
- enables `AFL_NO_UI=1` for log-friendly output
- enables `AFL_SKIP_CPUFREQ=1`
- enables `AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1`, which is often needed on Ubuntu cloud VMs because of the kernel `core_pattern` setting
- runs AFL++ for the requested number of seconds
- prints a summary from the saved `fuzzer_stats` file at the end

## Step 8: Run The Baseline Target Manually

From the project root:

```bash
./scripts/run-zchunk-afl.sh
```

By default this uses:

- target repo: `targets/zchunk`
- input corpus: `fuzzing/zchunk/in`
- output dir: `fuzzing/zchunk/out`
- build dir: `build-afl`
- target command: `build-afl/src/unzck -c @@`

Useful optional environment variables:

```bash
AFL_SKIP_CPUFREQ=1 ./scripts/run-zchunk-afl.sh
```

```bash
AFL_NO_UI=1 AFL_TIMEOUT_MS=2000+ ./scripts/run-zchunk-afl.sh
```

```bash
AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1 AFL_NO_UI=1 ./scripts/run-zchunk-afl.sh
```

## Step 9: Run Alternate zchunk Targets From The Same Build

Use the generic wrappers when you want to fuzz a different instrumented executable or a different fixed argument set.

### Short pilot for `zck_read_header -c @@`

```bash
./scripts/run-zchunk-afl-target-pilot.sh 120 \
  "$PWD/targets/zchunk" \
  "$PWD/fuzzing/zchunk/in" \
  "$PWD/fuzzing/zchunk/out-read-header-chunks" \
  build-afl \
  zck_read_header \
  -c
```

### Short pilot for `zck_read_header -f @@`

```bash
./scripts/run-zchunk-afl-target-pilot.sh 120 \
  "$PWD/targets/zchunk" \
  "$PWD/fuzzing/zchunk/in" \
  "$PWD/fuzzing/zchunk/out-read-header-verify" \
  build-afl \
  zck_read_header \
  -f
```

### Manual longer run for `zck_read_header -c @@`

```bash
AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1 AFL_SKIP_CPUFREQ=1 \
./scripts/run-zchunk-afl-target.sh \
  "$PWD/targets/zchunk" \
  "$PWD/fuzzing/zchunk/in" \
  "$PWD/fuzzing/zchunk/out-read-header-chunks" \
  build-afl \
  zck_read_header \
  -c
```

Practical rule:

- one AFL run should use one fixed command
- a different executable or different flags should use a different output directory

## Step 10: Summarize AFL++ Output

After a run finishes, print the saved summary again with:

```bash
./scripts/summarize-zchunk-afl-output.sh
```

This prints:

- run time
- exec count
- execs per second
- corpus size
- newly found corpus items
- coverage
- stability
- queue, crash, and hang counts

What to watch for in the AFL++ UI or stats:

- paths discovered
- execs per second
- hangs
- crashes
- whether new coverage keeps growing after the first few minutes

## Step 11: Inspect Crash Output

If AFL++ finds a crash, the interesting files will usually appear under:

- `fuzzing/zchunk/out/default/crashes/`

To reproduce one quickly:

```bash
./scripts/repro-zchunk-afl-crash.sh "$PWD/fuzzing/zchunk/out/default/crashes/<crash-file>"
```

If you built with ASan, rerun the reproducer with the same ASan-enabled binary so the report stays informative.

For alternate targets, pass the target name and any fixed target arguments after the build directory name. Example:

```bash
./scripts/repro-zchunk-afl-crash.sh \
  "$PWD/fuzzing/zchunk/out-read-header-chunks/default/crashes/<crash-file>" \
  "$PWD/targets/zchunk" \
  build-afl \
  zck_read_header \
  -c
```

## Step 12: What We Observed In The Tested Ubuntu Pilot

In the tested EC2 pilot run for the baseline `unzck -c @@` target:

- AFL++ loaded `13` seeds from the prepared corpus
- the corpus grew to `40` files after a `119` second run
- speed was about `2508` execs per second
- bitmap coverage reached `16.39%`
- stability was `100%`
- no crashes or hangs were found in the short pilot

For alternate targets, prior EC2 smoke tests also confirmed:

- `zck_read_header`, `zck_read_header -c`, and `zck_read_header -f` all ran successfully on a known-good `.zck` sample
- `zck_read_header -c` completed a `58` second pilot at about `495` execs/sec with `13.88%` bitmap coverage and no crashes
- `zck_read_header -f` completed a `54` second pilot at about `144` execs/sec with `15.08%` bitmap coverage and no crashes

That means:

- the alternate targets are viable
- `-c` is faster
- `-f` is slower but reaches slightly more coverage in short tests

## Recommended Order For This Project

On a small Ubuntu or EC2 machine:

1. build once with AFL++ instrumentation
2. fuzz `unzck -c @@` first
3. then fuzz `zck_read_header -c @@`
4. then fuzz `zck_read_header -f @@` if needed

This gives the cleanest progression from broad parsing to narrower header-focused fuzzing while keeping the workflow simple and repeatable.

- the build works
- the fuzzer is exercising real code
- the corpus is mutating productively
- the environment is stable enough for a longer run

## Recommended First Campaign

For the course project, start small:

1. Install the Ubuntu dependencies and verify `afl-fuzz` plus `afl-clang-fast`.
2. Build with `AFL_USE_ASAN=1` if you want stronger crash diagnostics.
3. Seed with the shipped `.zck` test files.
4. Run `./scripts/run-zchunk-afl-pilot.sh 120` first to validate the whole setup.
5. If the pilot looks healthy, run a longer campaign.
6. Reproduce every crash outside AFL++ before treating it as a real finding.

This keeps the workflow manageable and helps distinguish real target bugs from setup noise.

## Step 12: Launch A Longer Run

Once the pilot succeeds, a beginner-friendly next step is:

```bash
AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1 AFL_SKIP_CPUFREQ=1 ./scripts/run-zchunk-afl.sh
```

If you are on a remote machine, consider running that inside `tmux` so the fuzzing job survives a disconnected SSH session.

## Good Next Steps After The First Run

- minimize the corpus with `afl-cmin`
- minimize a crashing input with `afl-tmin`
- compare crashes against the CodeQL leads in `src/unzck.c`
- consider a narrower library-level harness later if CLI fuzzing plateaus

## Troubleshooting

### Problem: `libargp-standalone-dev` cannot be installed

On Ubuntu `24.04`, retry the package install without it.

### Problem: AFL++ aborts with a `core_pattern` message

This is common on cloud Ubuntu systems.

The easiest beginner fix is:

```bash
./scripts/run-zchunk-afl-pilot.sh 120
```

Or, if you are launching AFL++ manually:

```bash
AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1 ./scripts/run-zchunk-afl.sh
```

### Problem: AFL++ says there are no free CPU cores

This is common on a small EC2 instance if another AFL++ job is already running.

Recommended beginner fix:

- do not start a second fuzzing job on the same 2-core machine
- let the current run finish first

If you intentionally want to run despite the warning, AFL++ supports:

```bash
AFL_NO_AFFINITY=1 ./scripts/run-zchunk-afl.sh
```

But on a small cloud VM, that is usually not the best default.

### Problem: The build succeeds, but fuzzing is slow

The shipped seed corpus includes some large files close to `1 MB`, so a novice should expect a slower start.

That is acceptable for the first validation run.

If needed later:

- trim the corpus with `afl-cmin`
- temporarily start with fewer large seeds
- move to a narrower custom harness later

### Problem: `scripts/run-zchunk-afl.sh` says the input corpus is missing

Run:

```bash
./scripts/prepare-zchunk-afl-corpus.sh "$PWD/targets/zchunk"
```

## Notes On Scope

This setup intentionally starts with the real CLI target instead of a custom in-process harness.

That is the right tradeoff for this project right now because:

- it is fast to get running
- it exercises production code
- it uses real `.zck` files immediately
- it gives us a baseline before we spend time on harness engineering

If we later need more throughput, we can build a custom harness around lower-level library entry points. For the first AFL++ pass, `unzck` is the cleanest place to start.
