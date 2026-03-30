# AFL++ Target Exploration For zchunk

## Purpose

This note records which `zchunk` targets were explored for AFL++, what was actually run on the Ubuntu EC2 machine, and what we observed.

The goal of this document is to keep a small experiment log instead of relying on memory.

This is not only a list of candidate targets. It is also the record of our actual fuzzing attempts, including runs that did not produce a crash.

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

Primary AFL command used for the baseline campaign:

```bash
afl-fuzz -i /home/ubuntu/Project2/fuzzing/zchunk/in \
  -o /home/ubuntu/Project2/fuzzing/zchunk/out \
  -m none -t 1000+ -- \
  /home/ubuntu/Project2/targets/zchunk/build-afl/src/unzck -c @@
```

## Targets Considered

### `unzck -c @@`

Why it is useful:

- reads attacker-controlled `.zck` files directly
- exercises real parsing plus decompression
- avoids creating output files because `-c` writes to stdout

Current status:

- this was the primary baseline target
- a short pilot run worked cleanly
- a longer EC2 run was completed without crashes

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

## Experiments Run

### Experiment 1: `unzck -c @@` pilot run

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

- this was a healthy baseline target
- it was broad and stable
- it looked worth extending into a longer run

### Experiment 2: `unzck -c @@` longer run

Observed from `fuzzing/zchunk/out/default/fuzzer_stats` on the Ubuntu machine:

- start time: `1774838166`
- last update: `1774875850`
- runtime: `37,684` seconds, about `10.47` hours
- execs done: `33,211,546`
- execs/sec: `881.32`
- execs/sec in last minute: `652.85`
- corpus count: `46`
- corpus found: `33`
- stability: `100.00%`
- bitmap coverage: `16.46%`
- saved crashes: `0`
- saved hangs: `0`
- edges found: `357`
- total edges: `2169`
- AFL banner: `/home/ubuntu/Project2/targets/zchunk/build-afl/src/unzck`
- AFL version: `++4.09c`

Important command line recorded by AFL++:

```bash
afl-fuzz -i /home/ubuntu/Project2/fuzzing/zchunk/in -o /home/ubuntu/Project2/fuzzing/zchunk/out -m none -t 1000+ -- /home/ubuntu/Project2/targets/zchunk/build-afl/src/unzck -c @@
```

Interpretation:

- AFL++ was running productively, not stuck
- the campaign maintained perfect stability
- the corpus still expanded beyond the original seeds
- no crash or hang was found even after more than `33` million executions

Conclusion from this experiment:

- `unzck -c @@` was a valid first target
- but it did not produce a quick vulnerability signal for this project
- after this longer run, this route was deprioritized

### Experiment 3: `zck_read_header -f @@` short pilot

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

### Experiment 4: `zck_read_header -c @@` short pilot

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

Recommended next long run command:

```bash
AFL_NO_UI=1 AFL_SKIP_CPUFREQ=1 AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1 \
./scripts/run-zchunk-afl-target.sh \
  "$PWD/targets/zchunk" \
  "$PWD/fuzzing/zchunk/in" \
  "$PWD/fuzzing/zchunk/out-read-header-chunks" \
  build-afl \
  zck_read_header \
  -c
```

How to analyze that run's output:

```bash
./scripts/summarize-zchunk-afl-output.sh "$PWD/fuzzing/zchunk/out-read-header-chunks"
```

Important output locations for this run:

- stats: `fuzzing/zchunk/out-read-header-chunks/default/fuzzer_stats`
- queue: `fuzzing/zchunk/out-read-header-chunks/default/queue/`
- crashes: `fuzzing/zchunk/out-read-header-chunks/default/crashes/`
- hangs: `fuzzing/zchunk/out-read-header-chunks/default/hangs/`

Crash reproduction for this target:

```bash
./scripts/repro-zchunk-afl-crash.sh \
  "$PWD/fuzzing/zchunk/out-read-header-chunks/default/crashes/<crash-file>" \
  "$PWD/targets/zchunk" \
  build-afl \
  zck_read_header \
  -c
```

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

## Outcome Of The zchunk AFL Attempt

What this experiment series established:

- the AFL++ setup worked correctly
- the target binary was stable under fuzzing
- the seed corpus was usable and grew under mutation
- alternate parser-oriented targets were also viable
- no crash or hang was found in the baseline long run

This means the effort was still useful:

- it validated the fuzzing workflow
- it gave us real measurements instead of guesses
- it let us make an informed decision to stop investing more time in this specific route

## Recommendation Right Now

Recommended order:

1. Treat the `unzck -c @@` campaign as a completed experiment rather than the main active route.
2. If `zchunk` fuzzing is revisited, try `zck_read_header -c @@` first as the next narrow parser target.
3. Use `zck_read_header -f @@` when deeper verification logic is worth the speed tradeoff.
4. Otherwise, shift project effort toward the stronger non-fuzzing evidence path, such as CodeQL and manual code review.

## Current Bottom Line

What we have so far:

- no confirmed crash
- one substantial `unzck -c @@` run with more than `33` million executions
- stable and productive AFL behavior
- viable alternate targets, but no vulnerability signal strong enough to justify continued focus here

That means the current zchunk AFL setup was valid and informative, but it did not produce a reportable vulnerability from the experiments performed.
