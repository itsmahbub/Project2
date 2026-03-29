# Step-by-Step: Small-Scale AFL++ On journalot In Ubuntu

## Goal

Run a small, honest AFL++ experiment against `jtaylortech/journalot` and document it in a way that a beginner can reproduce.

## Important Scope Note

`journalot` is not a native C parser like `zchunk`.

It is:

- a Bash CLI script
- heavily oriented around filesystem operations
- interactive in some code paths
- lower-confidence for classic memory-corruption fuzzing

That means:

- this is a weaker vulnerability target than `zchunk`
- AFL++ is still usable for lightweight robustness testing
- any findings are more likely to be shell-logic, path-handling, or option-handling issues than memory-safety bugs

This guide is for a small exploratory fuzzing pass, not a claim that `journalot` is an especially strong AFL target.

## What We Chose To Fuzz

We prepared two simple file-driven harnesses:

- `scripts/journalot-afl-date-harness.sh`
- `scripts/journalot-afl-search-harness.sh`

Why these two:

- they consume attacker-controlled text from a file
- they avoid the fully interactive editor workflow
- they run inside an isolated throwaway journal directory
- they do not touch a real user journal or config

The two target shapes are:

- `journal --date "<payload>"`
- `journal --search "<payload>"`

## Step 1: Install Ubuntu Dependencies

Run:

```bash
sudo apt update
sudo apt install -y git bash coreutils grep findutils sed util-linux afl++
```

If AFL++ is already installed for `zchunk`, you may already have everything you need.

## Step 2: Clone journalot

From the project root:

```bash
mkdir -p targets
git clone https://github.com/jtaylortech/journalot.git targets/journalot
```

At the time of testing, the observed commit was:

- `8a976df`

## Step 3: Prepare Seed Corpora

Prepare the date corpus:

```bash
./scripts/prepare-journalot-afl-corpus.sh date
```

Prepare the search corpus:

```bash
./scripts/prepare-journalot-afl-corpus.sh search
```

This creates:

- `fuzzing/journalot/date-in`
- `fuzzing/journalot/search-in`

## Step 4: Smoke-Test The Harnesses

Test the date harness:

```bash
./scripts/journalot-afl-date-harness.sh "$PWD/targets/journalot" "$PWD/fuzzing/journalot/date-in/yesterday.txt"
echo $?
```

Test the search harness:

```bash
./scripts/journalot-afl-search-harness.sh "$PWD/targets/journalot" "$PWD/fuzzing/journalot/search-in/work.txt"
echo $?
```

Expected result:

- exit code `0` for both

## Step 5: Run A Small AFL++ Date Fuzzing Pass

From the project root:

```bash
mkdir -p fuzzing/journalot/out-date
AFL_NO_UI=1 AFL_SKIP_CPUFREQ=1 AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1 \
timeout 120s \
afl-fuzz -i "$PWD/fuzzing/journalot/date-in" -o "$PWD/fuzzing/journalot/out-date" -m none -t 1000+ -- \
  "$PWD/scripts/journalot-afl-date-harness.sh" "$PWD/targets/journalot" @@
```

This is intentionally short.

For `journalot`, the purpose is:

- validate that the harness is stable
- see whether AFL can mutate inputs productively
- check for obvious shell-script crashes or hangs

## Step 6: Run A Small AFL++ Search Fuzzing Pass

From the project root:

```bash
mkdir -p fuzzing/journalot/out-search
AFL_NO_UI=1 AFL_SKIP_CPUFREQ=1 AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1 \
timeout 120s \
afl-fuzz -i "$PWD/fuzzing/journalot/search-in" -o "$PWD/fuzzing/journalot/out-search" -m none -t 1000+ -- \
  "$PWD/scripts/journalot-afl-search-harness.sh" "$PWD/targets/journalot" @@
```

## Step 7: Inspect Results

Look at:

- `fuzzing/journalot/out-date/default/fuzzer_stats`
- `fuzzing/journalot/out-date/default/crashes`
- `fuzzing/journalot/out-date/default/hangs`
- `fuzzing/journalot/out-search/default/fuzzer_stats`
- `fuzzing/journalot/out-search/default/crashes`
- `fuzzing/journalot/out-search/default/hangs`

You can count files quickly with:

```bash
find fuzzing/journalot/out-date/default/crashes -type f ! -name README.txt | wc -l
find fuzzing/journalot/out-search/default/crashes -type f ! -name README.txt | wc -l
```

## What We Observed While Setting This Up

From the initial repository inspection:

- `journalot` is a Bash script at `bin/journal`
- it loads configuration with `source "$CONFIG_FILE"`
- it uses `date -d` for natural-language date parsing on Linux
- it relies heavily on filesystem operations and optional git syncing

That led to the harness design:

- isolate `$HOME`, `XDG_CONFIG_HOME`, and `JOURNAL_DIR`
- precreate a local git repo for the `--date` harness so the script does not prompt
- set `EDITOR=true` so the editor phase is non-interactive

## What Happened In Practice

On the tested Ubuntu EC2 machine:

- both harnesses smoke-tested successfully
- AFL++ normal mode rejected the harnesses because they are shell scripts
- AFL++ dumb mode with `/usr/bin/bash` could be started, but it produced `map size = 0`
- that means there was no useful coverage signal for AFL to guide mutations
- no crash was found during the small test

So the important conclusion is:

- the setup is reproducible
- but `journalot` is a weak AFL++ target in practice
- it should not replace `zchunk` as the main fuzzing target

## How To Interpret Results

If you do not find crashes:

- that is not surprising
- this target is still useful as a documented comparison point against `zchunk`
- the experiment still shows that `journalot` is a much less natural AFL target

If you do find a crash or hang:

- reproduce it outside AFL first
- confirm it is in `journalot` itself and not just an external command behavior
- document the exact payload and environment variables used

## Recommendation

For this project:

1. Keep `zchunk` as the primary fuzzing target.
2. Treat `journalot` as a lightweight comparison target.
3. Use the `--date` harness first.
4. Use the `--search` harness as a secondary low-cost experiment.

That keeps the work reproducible without over-investing in a weaker target.
