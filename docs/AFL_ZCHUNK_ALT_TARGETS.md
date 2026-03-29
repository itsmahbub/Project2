# Alternate AFL++ Targets For zchunk

## Goal

This note records the next-best `zchunk` AFL++ targets after the baseline:

- `unzck -c @@`

The goal is to make alternate target runs repeatable and easy to compare.

## Recommended Order

Recommended order after `unzck`:

1. `zck_read_header -c @@`
2. `zck_read_header -f @@`
3. `zck_read_header @@`

Why this order:

- all three enter real `.zck` parsing code
- they are narrower than `unzck`
- they avoid the extra decompression work in the baseline target
- `-c` and `-f` reach slightly different validation and metadata paths

## Target Meanings

### `zck_read_header @@`

- parses the archive header
- prints metadata
- good for narrow header-focused fuzzing

### `zck_read_header -c @@`

- parses the header
- walks chunk information
- likely the most useful next narrow target

### `zck_read_header -f @@`

- parses the header
- validates checksums
- reaches more verification logic

## Generic Runner Scripts

Use:

- `scripts/run-zchunk-afl-target.sh`
- `scripts/run-zchunk-afl-target-pilot.sh`

These let you fuzz any built binary under `targets/zchunk/build-afl/src/` without creating a new one-off script every time.

## Example Commands

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

## Notes From Prior EC2 Testing

What was already confirmed:

- `zck_read_header`, `zck_read_header -c`, and `zck_read_header -f` all smoke-tested successfully on a known-good `.zck` sample
- `zck_read_header -c` completed a 58-second pilot with about `495` execs/sec, `19` new corpus items, `13.88%` bitmap coverage, and no crashes
- `zck_read_header -f` completed a 54-second pilot with about `144` execs/sec, `24` new corpus items, `15.08%` bitmap coverage, and no crashes

That means:

- the alternate targets are viable
- `-c` is faster
- `-f` is slower but reaches slightly more coverage in short tests

## Practical Advice

On a small EC2 machine:

- run only one AFL job at a time
- finish the baseline `unzck` run first
- then move to `zck_read_header -c @@`

That gives the cleanest comparison between broad parsing and narrow header parsing.

If `zck_read_header -c @@` plateaus without crashes, follow it with `zck_read_header -f @@`.
