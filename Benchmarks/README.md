# SwiftyShell Benchmarks

Performance benchmarks for SwiftyShell's execution engine, built on
[ordo-one/benchmark](https://github.com/ordo-one/benchmark) (formerly package-benchmark). They live
in their own package so SwiftyShell itself carries no benchmark dependency and keeps its Swift 6.2 floor.

Requires Swift 6.3 or later on macOS 15+ or Linux. On 6.3 the benchmark package counts allocations with
its built-in malloc interposer; older toolchains need jemalloc installed instead.

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

## CI

`.github/workflows/benchmark.yml` runs on pull requests that touch `Package.swift`,
`Sources/SwiftyShell/Core/`, `Sources/SwiftyShell/Internal/`, or `Benchmarks/`. It benchmarks `main`
and the pull request on the same runner, then runs `baseline check main pull_request`.

Only allocation counts (`Malloc (total)`) can fail the check; the thresholds live next to each
benchmark in `SwiftyShellBenchmarks.swift`:

| Benchmark | Gate |
|---|---|
| `builder/command-20-args` | Any extra allocation in the median (the count is deterministic) |
| Every process benchmark | More than 2% extra allocations at p50 or p75 |

Wall-clock time, CPU time, and peak memory are marked report-only: identical runs differed by over 20%
even on an idle local machine, and shared runners are noisier. The job summary shows the full comparison, so review it on engine changes. When a
change intentionally adds allocations, loosen that benchmark's threshold in the same pull request.

To reproduce the CI check locally:

```bash
git switch main && swift package --disable-sandbox benchmark baseline update main
git switch my-branch && swift package --disable-sandbox benchmark baseline update pull_request
swift package benchmark baseline check main pull_request
```

## Reading the memory numbers

`Memory (resident peak)` is the process-wide high-water mark. On macOS, freed large allocations
stay resident in libmalloc's large-allocation cache until memory pressure, so the capture
benchmark's peak grows across iterations even though live heap memory does not (verified with
`heap`: about 150 KB live after nine 64 MiB captures). Use `Malloc (total)` and wall/CPU time to
compare changes. Tables scale large counts, so `27` under `Malloc (total)` for a 64 MiB benchmark
means about 27 thousand allocations; check the unit in the table header.
