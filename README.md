# Analyzing Syntax, Semantics, and Memory Management

Coursework repository for MSCS 632, Advanced Programming Languages. Every program
here was compiled and executed; the captured output is in `logs/`.

## Results are captured on two platforms

| Log | Platform | Status |
|---|---|---|
| `logs/full_run_linux.txt` | Ubuntu 24.04, arm64, in the container | **Authoritative.** All numbers in the report come from this run. |
| `logs/full_run_macos.txt` | macOS on Apple Silicon, Apple Clang | Secondary. Source of the compiler-recovery comparison in Part 1 (Figure 8): Apple Clang reports the same missing semicolon once, where g++ reports it twice. |


Valgrind has no aarch64 Darwin port, so it cannot run natively on Apple Silicon
at all. The assignment requires a memory profiling tool, so the authoritative
run happens inside a **native arm64** Linux container. The container is not
emulated: `--platform linux/arm64` on Apple Silicon runs at native speed, which
matters because Valgrind under CPU emulation is unusably slow.

## Reproducing

One command, from a clean checkout, on Apple Silicon or any arm64 Linux host:

```bash
make run
```

That builds the image, runs everything inside it, writes
`logs/full_run_linux.txt`, and then checks the log against the assignment's
acceptance criteria. Equivalent long form:

```bash
docker build --platform linux/arm64 -t apl-env .
docker run --rm --platform linux/arm64 apl-env ./run_all.sh
```

Or with Compose:

```bash
docker compose run --rm apl ./run_all.sh
```

The sources are baked into the image by the Dockerfile's `COPY`, and results
come back over stdout, so the run needs no bind mount and no Docker file
sharing. That also makes the image a hermetic artifact: the results depend on
nothing outside the build. `make shell-mount` gives the live-edit bind-mount
workflow instead, for hosts where Docker Desktop file sharing works.

Other targets:

| Command | Effect |
|---|---|
| `make shell` | interactive shell in the same container |
| `make shell-mount` | same, but bind-mounts the working tree for live edits |
| `make macos` | host run without Valgrind, writes `logs/full_run_macos.txt` |
| `make verify` | re-check `logs/full_run_linux.txt` against the acceptance criteria |

`run_all.sh` aborts with an explicit message if `valgrind`, `g++`, `rustc`,
`javac`, `node`, or `python3` is missing, rather than emitting an empty section.
`--no-valgrind` overrides that for the host run only, and stamps the log
NOT AUTHORITATIVE.

## Layout

```
Dockerfile                                      native arm64 Ubuntu 24.04 toolchain
Makefile / docker-compose.yml                   one-command reproduction
run_all.sh                                      runs everything, prints toolchain table first
tools/bench.py                                  5 runs per program, median + range, peak RSS
tools/verify_log.sh                             checks a log against the acceptance criteria
part1/
  section1/
    working/     sum.py, sum.js, sum.cpp        working baselines
    broken/      nine files with deliberate errors, three per language
  section2/
    semantics_demo.py / .js / .cpp              type systems, closures, numeric model
    type_error.cpp                              does not compile, by design
part2/
  cpp/manual_memory.cpp                         new/delete, leak flag, dangling flag
  java/MemoryDemo.java                          garbage collection and retention leak
  rust/src/main.rs                              ownership, borrowing, deterministic drop
  rust/use_after_move.rs                        does not compile, by design
  rust/dangling_ref.rs                          does not compile, by design
logs/                                           captured output, see table above
```

Three files are expected to fail compilation. That failure is the result being
demonstrated, not a defect:

- `part1/section2/type_error.cpp` (string plus int rejected statically)
- `part2/rust/use_after_move.rs` (E0382, borrow of moved value)
- `part2/rust/dangling_ref.rs` (E0106, missing lifetime specifier)

## Method notes

**Timing.** Each memory program runs five times. The report quotes the median
and the range, not a single run. Two timings are recorded: the program's own
`elapsed:` line, which measures only the allocation loop, and wall-clock process
lifetime, which for Java includes JVM startup and is not comparable across
languages. The report uses the in-program figure.

**Peak memory.** Measured with `/usr/bin/time -v` where GNU time is available
(it is in the container), falling back to `getrusage(2)` on the child via
`wait4` where it is not (macOS ships BSD `time`, which has no `-v`). Each
figure in the log states which method produced it. The fallback is not an equal
alternative on Linux: the child inherits the measuring interpreter's resident
pages across `fork()` and the kernel does not reset the RSS high-water mark on
`execve`, which puts an ~8 MB floor under every reading and swamps programs
smaller than that. macOS does reset the mark, so the fallback is sound there.

**Garbage collector.** `java` is invoked with `-XX:+UseG1GC` pinned. Without it
the JVM's ergonomics pick Serial on a small container and G1 on a larger host,
and every GC line in the log changes with the machine.

**Optimization level for profiling.** The C++ memory program is built twice:
`-O2` for timing, and `-O0` for Valgrind. At `-O2` the compiler is permitted to
elide a heap allocation whose result is never read, which deletes the deliberate
leak and makes Valgrind report a clean run. The program's source is identical in
both builds; only the flag differs.

## Memory profiling commands

```bash
g++ -std=c++17 -g -O0 -o mem_cpp part2/cpp/manual_memory.cpp
valgrind --leak-check=full --show-leak-kinds=all ./mem_cpp            # clean: 0 bytes in use at exit
valgrind --leak-check=full --show-leak-kinds=all ./mem_cpp --leak     # 1,024,000 bytes definitely lost
valgrind --leak-check=full ./mem_cpp --dangle                         # invalid read of size 4

cd part2/java && javac MemoryDemo.java && java -XX:+UseG1GC -Xlog:gc -Xmx512m MemoryDemo
```
