### Goal

Identify, validate, and responsibly disclose a non-web vulnerability in a real open source application on GitHub.

### Current Direction

We are prioritizing a native-code target where a memory-safety bug is realistic, ideally a buffer overflow or closely related parsing bug discoverable with static analysis and fuzzing.

### Working Docs

- [Project Plan](docs/PLAN.md)
- [Target Shortlist](docs/TARGETS.md)
- [CodeQL Setup](docs/CODEQL_SETUP.md)
- [CodeQL on Linux](docs/CODEQL_LINUX.md)
- [Step-by-Step Linux Guide for zchunk + CodeQL](docs/CODEQL_ZCHUNK_LINUX_STEP_BY_STEP.md)
- [zchunk CodeQL Workflow](docs/ZCHUNK_CODEQL.md)
- [Step-by-Step Ubuntu Guide for AFL++ on zchunk](docs/AFL_ZCHUNK_UBUNTU.md)

### Workspace Layout

- `docs/`: planning notes and target triage
- `codeql/`: CodeQL notes, queries, and findings
- `scripts/`: local helper scripts for repeatable analysis
- `fuzzing/`: AFL++ setup, harness notes, seed corpus, crashes
- `disclosure/`: responsible disclosure drafts and timelines
- `artifacts/`: screenshots, minimized PoCs, and report assets
