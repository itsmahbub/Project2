# Project Plan

## Objective

Find a real vulnerability in a non-web open source project, validate it safely, propose a fix, and prepare a responsible disclosure package.

## Preferred Vulnerability Class

Primary: buffer overflow or nearby memory-corruption bug in native code.

Fallbacks:

- out-of-bounds read or write
- integer overflow leading to unsafe allocation or copy
- use-after-free
- unsafe file parsing logic with security impact

## Current Recommendation

Start with `zchunk/zchunk` as the first serious candidate.

Why it fits:

- non-web and real-world useful
- native C code, so memory-safety bugs are plausible
- parses attacker-controlled `.zck` files
- small enough to reason about compared to very large projects
- good match for CodeQL triage before AFL++ fuzzing

## Phases

### 1. Finalize target

- confirm the repository is active, open source, and in the right size range
- confirm local buildability on our machine
- confirm there is a clear input surface for fuzzing
- check for an existing security policy or disclosure contact

### 2. Static triage with CodeQL

- build a CodeQL database for the target
- run standard C/C++ security queries
- review warnings around parsing, memory copies, allocation math, and bounds checks
- identify 1 to 3 functions worth prioritizing for fuzzing

### 3. Fuzzing setup with AFL++

- compile with AFL instrumentation
- pick a narrow target surface such as one parser entry point or one command handling a file
- create a small seed corpus of valid and slightly malformed inputs
- enable crash saving and corpus minimization

### 4. Crash triage

- reproduce crashes deterministically
- classify root cause
- minimize the crashing input
- confirm whether the issue is in the target project and not only in a dependency

### 5. Patch and validate

- propose the smallest correct fix
- rebuild and rerun the reproducer
- rerun a short fuzzing pass to confirm the crash is gone
- document impact, trigger conditions, and fix rationale

### 6. Responsible disclosure

- prepare a short advisory draft
- contact the maintainer privately if possible
- share the PoC only through the agreed disclosure channel
- wait for maintainer guidance before public release

### 7. Class deliverables

- concise timeline of work
- methodology summary
- evidence from CodeQL and AFL++
- vulnerability description
- reproduction steps
- proposed fix and disclosure status

## Concrete Near-Term Tasks

1. Clone and build the top candidate locally.
2. Record build instructions and dependencies in `docs/`.
3. Run initial CodeQL analysis and save the interesting findings.
4. Choose one parser path for AFL++.
5. Prepare a starter seed corpus.
6. Run a short pilot fuzzing campaign before any long run.

## Decision Rules

- Prefer bugs in the main project code over bugs only reachable in third-party libraries.
- Prefer simple file-based inputs over complex interactive targets.
- Prefer a reproducible medium-severity bug over an impressive but unstable result.
- Stop pursuing a target if setup cost becomes disproportionate to likely payoff.
