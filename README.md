# Analyzing Syntax, Semantics, and Memory Management

Coursework repository for Advanced Programming Languages. Every program here was
compiled and executed; the captured output is in `logs/full_run.txt`.

## Toolchain used

| Tool | Version |
|---|---|
| Python | 3.12.3 |
| Node.js | 22.22.2 |
| g++ | 13.3.0 (Ubuntu 24.04) |
| OpenJDK | 21.0.10 |
| rustc | 1.98.0 |
| Valgrind | 3.22.0 |

## Layout

```
part1/
  section1/
    working/     sum.py, sum.js, sum.cpp        working baselines
    broken/      six files with deliberate errors, three per failure class
  section2/
    semantics_demo.py / .js / .cpp              type systems, closures, numeric model
    type_error.cpp                              does not compile, by design
part2/
  cpp/manual_memory.cpp                         new/delete, leak flag, dangling flag
  java/MemoryDemo.java                          garbage collection and retention leak
  rust/src/main.rs                              ownership, borrowing, deterministic drop
  rust/use_after_move.rs                        does not compile, by design
  rust/dangling_ref.rs                          does not compile, by design
logs/full_run.txt                               complete captured output
run_all.sh                                      reproduces every result above
```

## Reproducing

```bash
./run_all.sh
```

Three files are expected to fail compilation. That failure is the result being
demonstrated, not a defect:

- `part1/section2/type_error.cpp` (string plus int rejected statically)
- `part2/rust/use_after_move.rs` (E0382, borrow of moved value)
- `part2/rust/dangling_ref.rs` (E0106, missing lifetime specifier)

## Memory profiling commands

```bash
g++ -std=c++17 -g -O2 -o mem_cpp part2/cpp/manual_memory.cpp
valgrind --leak-check=full ./mem_cpp            # clean: 0 bytes in use at exit
valgrind --leak-check=full ./mem_cpp --leak     # 1,024,000 bytes definitely lost
valgrind --leak-check=full ./mem_cpp --dangle   # invalid read of size 4

cd part2/java && javac MemoryDemo.java && java -Xlog:gc -Xmx512m MemoryDemo
```
