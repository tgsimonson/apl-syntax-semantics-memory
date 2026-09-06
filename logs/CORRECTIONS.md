# Report corrections

**Status: applied to the report on 2026-09-06.** Paragraph 1 (environment and
provenance), Figures 13, 14, 15 and 16, Table 3 and its caption, and the peak
memory discussion have all been updated in
`syntax-semantics-memory-report.docx`. This file remains as the record of what
changed and why. Figures 7-9 needed no change; see below.

Every figure below comes from `logs/full_run_linux.txt`, the authoritative run
(native arm64 Ubuntu 24.04 container, Valgrind working). `logs/full_run_macos.txt`
is the secondary Apple Clang artifact. The report's current figures come from an
earlier x86_64 run that this one supersedes.

## Environment section

| Field | Report says | Should say |
|---|---|---|
| Platform | Linux x86_64 | Linux **aarch64** (Ubuntu 24.04.4 LTS, native arm64 container on Apple Silicon) |
| Python | 3.12.3 | 3.12.3 (unchanged) |
| Node.js | 22.22.2 | **22.23.2** |
| g++ | 13.3.0 | 13.3.0 (unchanged) |
| OpenJDK | 21.0.10 | **21.0.12** |
| rustc | 1.98.0 | **1.98.1** |
| Valgrind | 3.22.0 | 3.22.0 (unchanged) |
| Garbage collector | Serial (implicit) | **G1, pinned explicitly with `-XX:+UseG1GC`** |

## Divergence 1 — Valgrind

Fixed. All three runs now produce output, in the container. No text change needed
to the Valgrind narrative, but see the new finding below, which does change how
Figure 13 must be produced.

**New finding, not in your list.** Figure 13 (the 1,024,000-byte leak at
`manual_memory.cpp:25`) was **not reproducible from the original log**. The
original `--leak` run reported `ERROR SUMMARY: 0 errors` and no lost bytes,
because at `-O2` the compiler is permitted to elide a heap allocation whose
result is never read, which deleted the deliberate leak outright. The program is
now built twice: `-O2` for timing and `-O0` for profiling. At `-O0` the leak
appears exactly as Figure 13 claims. Figure 13's numbers are correct as printed;
what changed is that they are now actually produced by the run. If the report
states the Valgrind command anywhere, it must show the `-O0` build.

## Divergence 2 — C++ compiler

**Figures 7, 8, and 9 need no change.** The canonical run is g++ 13.3.0 again, and
its diagnostics on arm64 are identical to the original x86_64 output, including
the two cascading errors at `7:5` and `7:21` for one missing semicolon.

The Clang behaviour is worth adding as a contrast, sourced from
`logs/full_run_macos.txt`:

| | g++ 13.3.0 | Apple Clang 21.0.0 |
|---|---|---|
| Errors for one missing semicolon | 2 (cascading) | 1 |
| Location reported | `7:5`, at the following token | `6:18`, at the actual site |
| Terminating line | none | `1 error generated.` |

That contrast strengthens the syntax-error analysis rather than undermining it:
the same defect yields different error counts and different blamed lines
depending on the compiler's recovery strategy.

## Divergence 3 — Java garbage collector

Every Serial GC line in the report is wrong. G1 is now pinned. Replacement lines:

| Phase | Report (Serial) | Canonical (G1) |
|---|---|---|
| During churn | three young collections, `18M->1M(61M)` each | **one** young collection, `24M->1M(64M)` |
| Heap after churn | 3 MB | **31 MB** |
| First `System.gc()` | `3M->1M(61M)` | `31M->1M(8M)` |
| Retention phase, full GC | `21M->21M(61M)` | `21M->21M(37M)` |
| After `clear()` | `21M->1M(61M)` | `21M->1M(10M)` |

**Figure 15** currently reads "Three young-generation collections during the
allocation loop." Under G1 there is **one** young collection during the loop
(`24M->1M(64M)`). The caption and the surrounding sentence both need rewriting.
The underlying point survives: the collector reclaims the churned blocks
automatically, and it does so in a single pause rather than three.

**Figure 16** ("A full collection reclaiming nothing because every object remains
reachable") is still correct in substance. Update the numbers to
`GC(8) Pause Full (System.gc()) 21M->21M(37M) 5.275ms`.

## Divergence 4 — Timings and Table 3

Each program now runs five times; the report should quote median and range, not a
single run.

### Table 3, replacement values

| Row | C++ | Rust (-O) | Java (JDK 21) |
|---|---|---|---|
| Elapsed, 200k blocks (median of 5) | **2 ms** (range 2-3) | **10 ms** (range 10-10) | **12 ms** (range 8-13) |
| Peak resident memory | **2.9 MB** | **1.6 MB** | **74.7 MB** |
| Heap allocations | 200,002 | 200,013 | not directly comparable |
| Definitely lost (clean) | 0 bytes | 0 bytes | not applicable |
| Dangling pointer possible | yes, runtime | no, rejected | no, unreachable |
| Leak possible | yes, forgotten free | difficult | yes, by retention |
| Error found by | Valgrind at runtime | rustc at compile time | profiler, if at all |

Old values for reference: C++ 4-5 ms / Rust 3 ms / Java 21-22 ms; peak memory
8 MB / 8 MB / 79 MB.

The caption "Measured across three runs each on the same container" becomes
**"Median of five runs each, with range, on the same container."**

### What actually changed, and why

- **Java is no longer an outlier.** 21-22 ms became 13 ms. The old figure was a
  single run on a different collector; G1 handles this allocation pattern better
  than Serial did, and the median of five is more stable.
- **Rust is now slower than C++,** 10 ms against 2 ms, reversing the report's
  claim that Rust was fastest. Both do the same amount of heap work: Valgrind
  counts 200,002 allocations for C++ and 200,013 for Rust. The difference is that
  Rust builds each block through `(0..64).map(...).collect()`, an iterator
  pipeline that materialises the `Vec`, and `black_box` deliberately blocks the
  optimisations that would otherwise hide that cost. C++ writes into a raw
  `new int[64]`. This is a real result on this platform, not a measurement
  artifact, and the report should state it rather than the old ordering.
- **Peak memory fell for C++ and Rust** (8 MB to 2.9 and 1.6 MB) because the old
  figures were measured with a method that inherited an ~8 MB floor from the
  measuring process. The Java figure, 79 MB to 74.7 MB, barely moved because it
  was always far above that floor. The report's argument -- that the JVM's
  resident cost dwarfs both -- is unaffected and if anything is stronger.

### Run-to-run stability

Two independent full container runs were captured. The GC log was identical
between them, line for line, and peak memory moved by at most 0.1 MB. The
medians moved by about a millisecond:

| | C++ | Rust | Java |
|---|---|---|---|
| Run A | 2 ms (2-3) | 11 ms (11-11) | 13 ms (9-14) |
| Run B (the log in this repo) | 2 ms (2-3) | 10 ms (10-10) | 12 ms (8-13) |

So the ordering -- C++ fastest by a wide margin, Rust and Java close together --
is stable, while the exact millisecond figures are not. The report should quote
the range, not a bare median, for exactly this reason.

### On the macOS timings in your list

Your single macOS run showed C++ 18 ms, Java 11 ms, Rust 10 ms. Across five runs
the macOS medians are C++ 9 ms, Java 10 ms, Rust 9 ms -- the three are within a
millisecond of each other, and the 18 ms C++ figure was a cold-start outlier. The
"Java beat C++" conclusion does not survive repetition on macOS, and does not hold
at all in the canonical Linux run. If the report mentions it, it should be framed
as platform-specific and measured over five runs.

## Screenshots

The five `[SCREENSHOT: ...]` markers should be taken against the container run:

```bash
make shell
./run_all.sh          # then screenshot the relevant sections
```

The Java GC marker currently reads "showing the 21M to 21M collection during
retention and 21M to 1M after clearing" -- both still accurate under G1.
