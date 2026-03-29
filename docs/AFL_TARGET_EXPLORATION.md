# AFL++ Target Exploration For zchunk

## Purpose

This note records which `zchunk` targets were explored for AFL++, what was actually run on the Ubuntu EC2 machine, and what we observed.

The goal of this document is to keep a small experiment log instead of relying on memory.

## Environment

The observations below came from:

- Ubuntu `24.04` on AWS EC2
- AFL++ `4.09c`
- Clang installed from Ubuntu packages
- `zchunk` built with the project helper script:
  - `scripts/build-zchunk-afl.sh`

Seed corpus source:

- `targets/zchunk/test/files/*.zck`

Prepared corpus size during the tested run:

- `14` files copied into `fuzzing/zchunk/in`

## Targets Considered

### `unzck -c @@`

Why it is useful:

- reads attacker-controlled `.zck` files directly
- exercises real parsing plus decompression
- avoids creating output files because `-c` writes to stdout

Current status:

- this is the primary baseline target
- a short pilot run worked cleanly
- a longer run is already in progress on EC2

### `zck_read_header @@`

Why it is useful:

- narrower than `unzck`
- enters `zck_init_read()` directly
- focuses on header parsing rather than full decompression

Smoke-test status:

- worked with a known-good seed

### `zck_read_header -c @@`

Why it is useful:

- walks chunk metadata after parsing the header
- still narrower than full decompression

Smoke-test status:

- worked with a known-good seed

### `zck_read_header -f @@`

Why it is useful:

- verifies the full file checksums after reading
- reaches more validation logic than plain header parsing

Smoke-test status:

- worked with a known-good seed

### `zck_delta_size @@ fixed-file`

Why it was considered:

- parses at least one attacker-controlled `.zck` file
- compares chunk structure between two archives

Why it was not prioritized yet:

- requires two input files
- less direct than `unzck` and `zck_read_header`
- more awkward for a novice AFL workflow

### `zck`

Why it was deprioritized:

- it creates `.zck` files rather than parsing attacker-controlled `.zck` input
- it is less aligned with the project’s file-parser vulnerability goal

### `zckdl`

Why it was deprioritized:

- adds `libcurl` and network behavior
- increases noise and dependency surface
- less suitable for a clean first file-fuzzing campaign

## Smoke Tests Performed

The following commands were verified against a known-good seed on the EC2 machine:

```bash
./targets/zchunk/build-afl/src/unzck -c ./fuzzing/zchunk/in/LICENSE.nodict.fodt.zck >/dev/null
```

```bash
./targets/zchunk/build-afl/src/zck_read_header ./fuzzing/zchunk/in/LICENSE.nodict.fodt.zck >/dev/null
```

```bash
./targets/zchunk/build-afl/src/zck_read_header -c ./fuzzing/zchunk/in/LICENSE.nodict.fodt.zck >/dev/null
```

```bash
./targets/zchunk/build-afl/src/zck_read_header -f ./fuzzing/zchunk/in/LICENSE.nodict.fodt.zck >/dev/null
```

All of those exited successfully with code `0`.

## Short Fuzzing Results

### `unzck -c @@`

Observed in the tested EC2 pilot run:

- runtime: about `119` seconds
- execs: `299,792`
- speed: about `2508` execs per second
- corpus grew from `13` loaded seeds to `40` items
- stability: `100%`
- bitmap coverage: `16.39%`
- crashes: `0`
- hangs: `0`

Interpretation:

- this is a healthy baseline target
- it is broad and stable
- it should remain the main long-run target unless a narrower target starts producing better results

### `zck_read_header -f @@`

Observed in the tested EC2 pilot run:

- runtime: about `54` to `118` seconds across short pilots
- execs/sec: about `144` in the later 54-second validation run
- corpus found: `24` to `27`
- bitmap coverage: `15.08%` to `15.17%`
- crashes: `0`
- hangs: `0`

Important qualitative notes from AFL++:

- the target was slower on some large seeds
- some seed files were considered huge
- some seeds were considered redundant

Interpretation:

- this is a viable secondary target
- it reaches meaningful parsing and validation logic
- it reaches slightly more coverage than `zck_read_header -c`
- it is substantially slower than `zck_read_header -c`
- it did not outperform `unzck` clearly enough in the short test to replace it as the main target yet

### `zck_read_header -c @@`

Observed in the later EC2 validation pilot:

- runtime: about `58` seconds
- execs done: `29,063`
- execs/sec: about `495`
- corpus found: `19`
- bitmap coverage: `13.88%`
- crashes: `0`
- hangs: `0`

Interpretation:

- the target itself still looks worth trying
- it is much faster than `zck_read_header -f`
- it found slightly less coverage than `zck_read_header -f` in the short run
- it is probably the best next narrow parser target after `unzck`

## Main Obstacles Observed

### Ubuntu `24.04` package difference

Problem:

- `libargp-standalone-dev` was not available from `apt`

Resolution:

- install the rest of the dependencies without that package

### AFL++ `core_pattern` abort on cloud Ubuntu

Problem:

- AFL++ complained that the system routes core dumps to an external utility

Resolution used for pilot runs:

```bash
AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1
```

Interpretation:

- acceptable for pilot runs
- a cleaner dedicated-fuzzer setup would change `/proc/sys/kernel/core_pattern`

### CPU affinity contention on a 2-core EC2 instance

Problem:

- AFL++ refused to start another job because both cores were already busy

Interpretation:

- do not run multiple AFL jobs casually on a small EC2 instance
- one long fuzzing job at a time is the safer default on this machine

## Recommendation Right Now

Recommended order:

1. Keep the long-running `unzck -c @@` campaign as the primary job.
2. After that run finishes, use `zck_read_header -c @@` as the next narrow parser target.
3. Use `zck_read_header -f @@` when you want deeper verification logic even at lower exec/sec.
4. Only after those CLI targets plateau, consider a custom in-process library harness.

## Current Bottom Line

What we have so far:

- no confirmed crash yet
- `unzck` is still the strongest first AFL target
- `zck_read_header -c` is the best next alternate target
- `zck_read_header -f` is a real secondary option when extra verification coverage is worth the speed tradeoff

That means the current fuzzing setup is valid and productive, but we do not yet have a vulnerability to report from the tested short runs.
