# SwiftyShell Benchmarks

Performance benchmarks for SwiftyShell's execution engine, built on
[package-benchmark](https://github.com/ordo-one/package-benchmark). They live in their own
package so SwiftyShell itself carries no benchmark dependency.

Requires Swift 6.3 or later (package-benchmark 1.36 needs it) on macOS 15+ or Linux.

```bash
cd Benchmarks

# Run everything
swift package --disable-sandbox benchmark

# Run a subset
swift package --disable-sandbox benchmark --filter "output/.*"

# Compare a change against main
git switch main && swift package --disable-sandbox benchmark baseline update main
git switch my-branch && swift package --disable-sandbox benchmark baseline compare main
```

## What is measured

| Benchmark | What it exercises |
|---|---|
| `run/true` | Per-process overhead: resolve, spawn, capture, and reap a command that does nothing |
| `output/capture-64MiB` | 64 MiB of stdout captured in memory |
| `output/discard-64MiB` | 64 MiB of stdout routed to `.discard` |
| `output/file-64MiB` | 64 MiB of stdout routed to `.file` |
| `pipeline/3-stage-64MiB` | `head | cat | wc -c` with 64 MiB flowing through kernel pipes |
| `builder/command-20-args` | Pure `Command` builder cost; no process is spawned |

## Reading the memory numbers

`Memory (resident peak)` is the process-wide high-water mark. On macOS, freed large allocations
stay resident in libmalloc's large-allocation cache until memory pressure, so the capture
benchmark's peak grows across iterations even though live heap memory does not (verified with
`heap`: about 150 KB live after nine 64 MiB captures). Use `Malloc (total)` and wall/CPU time to
compare changes.
