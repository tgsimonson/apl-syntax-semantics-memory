#!/usr/bin/env bash
# runs every program in this repository and prints the output
# usage: ./run_all.sh
set -u
hr(){ printf '\n========== %s ==========\n' "$1"; }

hr "PART 1 SECTION 1: working baselines"
python3 part1/section1/working/sum.py
node    part1/section1/working/sum.js
g++ -std=c++17 -o /tmp/sum part1/section1/working/sum.cpp && /tmp/sum

hr "PART 1 SECTION 1: Python syntax errors"
for f in part1/section1/broken/*.py; do echo "--- $f"; python3 "$f" 2>&1 | tail -6; done

hr "PART 1 SECTION 1: JavaScript syntax errors"
for f in part1/section1/broken/*.js; do echo "--- $f"; node "$f" 2>&1 | head -6; done

hr "PART 1 SECTION 1: C++ syntax errors"
for f in part1/section1/broken/*.cpp; do echo "--- $f"; g++ -std=c++17 -o /tmp/x "$f" 2>&1 | head -6; done

hr "PART 1 SECTION 2: semantics demos"
python3 part1/section2/semantics_demo.py
node    part1/section2/semantics_demo.js
g++ -std=c++17 -o /tmp/sem part1/section2/semantics_demo.cpp && /tmp/sem
echo "--- type_error.cpp (expected to fail) ---"
g++ -std=c++17 -o /tmp/te part1/section2/type_error.cpp 2>&1 | head -6

hr "PART 2: C++ manual memory"
g++ -std=c++17 -g -O2 -o /tmp/mem_cpp part2/cpp/manual_memory.cpp
/tmp/mem_cpp
echo "--- valgrind clean ---"
valgrind --leak-check=full /tmp/mem_cpp 2>&1 | grep -E "in use at exit|total heap usage|ERROR SUMMARY"
echo "--- valgrind --leak ---"
valgrind --leak-check=full /tmp/mem_cpp --leak 2>&1 | grep -E "definitely lost|ERROR SUMMARY"
echo "--- valgrind --dangle ---"
valgrind --leak-check=full /tmp/mem_cpp --dangle 2>&1 | grep -E "Invalid read|free'd|ERROR SUMMARY"

hr "PART 2: Java garbage collection"
(cd part2/java && javac MemoryDemo.java && java -Xlog:gc -Xmx512m MemoryDemo)

hr "PART 2: Rust ownership and borrowing"
rustc -O -o /tmp/mem_rust part2/rust/src/main.rs && /tmp/mem_rust
echo "--- use_after_move.rs (expected to fail) ---"
rustc part2/rust/use_after_move.rs 2>&1 | head -12
echo "--- dangling_ref.rs (expected to fail) ---"
rustc part2/rust/dangling_ref.rs 2>&1 | head -8
