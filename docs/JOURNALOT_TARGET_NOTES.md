# journalot AFL Notes

## Summary

We performed a small-scale AFL++ exploration for:

- `https://github.com/jtaylortech/journalot`

Observed repository shape:

- primary implementation is `bin/journal`
- language is Bash
- the tool is a journaling CLI, not a native parser

This matters because AFL++ works best on compiled targets with a clear file-parsing or stdin-parsing surface. `journalot` does not fit that model well.

## Repository Snapshot

Observed commit during setup:

- `8a976df`

## Chosen Experimental Targets

We prepared two lightweight file-driven harnesses:

- `scripts/journalot-afl-date-harness.sh`
- `scripts/journalot-afl-search-harness.sh`

These target:

- `journal --date "<payload>"`
- `journal --search "<payload>"`

Why these were chosen:

- they accept attacker-controlled text
- they avoid the fully interactive editor workflow
- they can be isolated inside a throwaway `$HOME` and journal directory

## Smoke-Test Results

Both harnesses ran successfully on the Ubuntu EC2 machine:

- date harness exit code: `0`
- search harness exit code: `0`

That means the harnesses themselves are usable for controlled execution.

## AFL++ Results

### Normal AFL++ mode

Attempt:

- run AFL++ directly against the harness scripts

Result:

- AFL++ aborted before fuzzing

Observed reason:

- AFL++ detected that the target program was a shell script

This is expected. AFL++ does not want to fuzz a shell wrapper in its normal coverage-guided mode.

### AFL++ dumb mode

Attempt:

- run `afl-fuzz -n` with `/usr/bin/bash` executing the harness scripts

Result:

- the run started
- AFL++ reported `map size = 0`
- all seeds collapsed into the same zero-coverage behavior
- no meaningful coverage guidance was available
- no crash was found

Interpretation:

- this is not a useful AFL target in practice
- even though the harnesses run, AFL is not getting actionable feedback

## Main Finding

The main result is not a vulnerability.

The main result is a target-quality conclusion:

- `journalot` is reproducible to inspect and execute
- it is a weak AFL++ target
- it is much worse than `zchunk` for this project

## Recommendation

Recommended use of `journalot` in this project:

1. keep it as a documented comparison target
2. do not invest major fuzzing time into it
3. keep `zchunk` as the main AFL++ target

If `journalot` is revisited later, it would make more sense to:

- do manual security review of shell logic
- look for config-file trust issues
- review path handling and git command usage

That is a better fit than classic AFL++ fuzzing.
