# Target Shortlist

## Selection Criteria

- non-web application
- open source with a public GitHub repository
- real practical use
- roughly near the low-hundreds star range when possible
- native implementation preferred for memory-safety research
- clear attacker-controlled input surface
- feasible to build and fuzz on a student project timeline

## Primary Candidate

### `zchunk/zchunk`

Why it looks strong:

- C project with custom file-format parsing
- command-line utility and library used for compressed chunked data
- attacker-controlled file input is central to the program
- likely easier to isolate for CodeQL and AFL++ than a very large desktop application

Planned first checks:

- inspect file parsing entry points
- verify local build path
- see whether existing tests or sample `.zck` files can seed fuzzing
- confirm current maintainer activity and disclosure channel

## Backup Candidates

### `hpjansson/chafa`

Pros:

- real and actively used terminal application
- native codebase
- file and image parsing surfaces

Risks:

- much larger star count than ideal
- some crashes may land in image dependencies instead of project-owned code

### `RickdeJager/stegseek`

Pros:

- native CLI tool with real-world use
- accepts attacker-controlled media files and command input

Risks:

- also larger than the desired star range
- security-oriented software can be harder to turn into a clean course-project disclosure

## Early Go or No-Go Checklist

- can we build it in under one sitting
- can we identify a parser entry point quickly
- can we produce or obtain sample inputs
- can we instrument it without major build-system surgery
- can we explain the vulnerability and patch clearly to the maintainer

If `zchunk` fails two or more of these checks, switch to the next candidate instead of forcing it.
