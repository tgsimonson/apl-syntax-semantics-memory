#!/usr/bin/env bash
# runs every program in this repository and prints the output
#
# usage: ./run_all.sh [--no-valgrind]
#
#   --no-valgrind   proceed even though no memory profiler is installed. The log
#                   is then marked NOT AUTHORITATIVE. This exists only so the
#                   macOS/Clang secondary artifact can be captured on a host
#                   where valgrind cannot run; never use it for the canonical run.
#
# The canonical run is inside the arm64 Linux container:  make run
set -u

RUNS=5
ALLOW_NO_VALGRIND=0
for arg in "$@"; do
  case "$arg" in
    --no-valgrind) ALLOW_NO_VALGRIND=1 ;;
    *) echo "run_all.sh: unknown argument '$arg'" >&2; exit 2 ;;
  esac
done

hr(){ printf '\n========== %s ==========\n' "$1"; }

# ---------------------------------------------------------------- preflight --
# A missing tool used to produce a silently empty section, which is how an
# entire missing valgrind went unnoticed. Abort loudly instead.
REQUIRED=(python3 node g++ javac java rustc valgrind)
missing=()
for t in "${REQUIRED[@]}"; do
  command -v "$t" >/dev/null 2>&1 || missing+=("$t")
done

if [ ${#missing[@]} -gt 0 ]; then
  only_valgrind=1
  for m in "${missing[@]}"; do [ "$m" = valgrind ] || only_valgrind=0; done

  if [ "$only_valgrind" = 1 ] && [ "$ALLOW_NO_VALGRIND" = 1 ]; then
    :   # explicitly acknowledged below in the banner
  else
    echo "" >&2
    echo "FATAL: required tool(s) not found on PATH: ${missing[*]}" >&2
    echo "" >&2
    for m in "${missing[@]}"; do
      case "$m" in
        valgrind) echo "  valgrind - the assignment requires a memory profiling tool." >&2
                  echo "             It has no aarch64 Darwin port, so it cannot run natively" >&2
                  echo "             on Apple Silicon. Use the container:  make run" >&2
                  echo "             To capture a non-authoritative host log anyway:" >&2
                  echo "                 ./run_all.sh --no-valgrind" >&2 ;;
        g++)      echo "  g++      - install build-essential (Linux) or Xcode CLT (macOS)." >&2 ;;
        rustc)    echo "  rustc    - install from https://rustup.rs" >&2 ;;
        javac|java) echo "  $m     - install a JDK (openjdk-21-jdk-headless)." >&2 ;;
        node)     echo "  node     - install Node.js 22 or newer." >&2 ;;
        python3)  echo "  python3  - install Python 3." >&2 ;;
      esac
    done
    echo "" >&2
    exit 1
  fi
fi

VALGRIND_OK=1
command -v valgrind >/dev/null 2>&1 || VALGRIND_OK=0

# ---------------------------------------------------------- toolchain table --
hr "TOOLCHAIN"
printf '%-14s %s\n' "captured:" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
printf '%-14s %s\n' "host:"     "$(uname -s) $(uname -r) $(uname -m)"
if [ -r /etc/os-release ]; then
  printf '%-14s %s\n' "distro:"  "$(. /etc/os-release; echo "$PRETTY_NAME")"
elif [ "$(uname -s)" = Darwin ]; then
  printf '%-14s %s\n' "distro:"  "macOS $(sw_vers -productVersion 2>/dev/null) ($(sysctl -n machdep.cpu.brand_string 2>/dev/null))"
fi
printf '%-14s %s\n' "python3:"  "$(python3 --version 2>&1)"
printf '%-14s %s\n' "node:"     "$(node --version 2>&1)"
printf '%-14s %s\n' "g++:"      "$(g++ --version 2>&1 | head -1)"
printf '%-14s %s\n' "javac:"    "$(javac -version 2>&1)"
printf '%-14s %s\n' "java:"     "$(java -version 2>&1 | head -1)"
printf '%-14s %s\n' "rustc:"    "$(rustc --version 2>&1)"
if [ "$VALGRIND_OK" = 1 ]; then
  printf '%-14s %s\n' "valgrind:" "$(valgrind --version 2>&1)"
else
  printf '%-14s %s\n' "valgrind:" "NOT INSTALLED"
  echo ""
  echo "  *** WARNING: THIS LOG IS NOT AUTHORITATIVE ***"
  echo "  Run with --no-valgrind on a host with no memory profiler. The three"
  echo "  valgrind sections below are absent, not passing. The canonical run is"
  echo "  the arm64 Linux container (make run)."
fi

# peak RSS is measured via getrusage in tools/bench.py, which needs no external
# tool; /usr/bin/time -v is reported here only as a cross-check.
if /usr/bin/time -v true >/dev/null 2>&1; then
  printf '%-14s %s\n' "time -v:" "available (GNU time), used as cross-check"
  TIME_V_OK=1
else
  printf '%-14s %s\n' "time -v:" "unavailable; peak RSS comes from getrusage(2) via tools/bench.py"
  TIME_V_OK=0
fi

hr "PART 1 SECTION 1: working baselines"
python3 part1/section1/working/sum.py
node    part1/section1/working/sum.js
g++ -std=c++17 -o /tmp/sum part1/section1/working/sum.cpp && /tmp/sum

hr "PART 1 SECTION 1: Python syntax errors"
for f in part1/section1/broken/*.py; do echo "--- $f"; python3 "$f" 2>&1 | tail -6; done

hr "PART 1 SECTION 1: JavaScript syntax errors"
for f in part1/section1/broken/*.js; do echo "--- $f"; node "$f" 2>&1 | head -6; done

hr "PART 1 SECTION 1: C++ syntax errors"
for f in part1/section1/broken/*.cpp; do echo "--- $f"; g++ -std=c++17 -o /tmp/x "$f" 2>&1 | head -8; done

hr "PART 1 SECTION 2: semantics demos"
python3 part1/section2/semantics_demo.py
node    part1/section2/semantics_demo.js
g++ -std=c++17 -o /tmp/sem part1/section2/semantics_demo.cpp && /tmp/sem
echo "--- type_error.cpp (expected to fail) ---"
g++ -std=c++17 -o /tmp/te part1/section2/type_error.cpp 2>&1 | head -8

hr "PART 2: C++ manual memory"
# two binaries on purpose:
#   -O2  timing build, matches how the program would really be compiled
#   -O0  profiling build. At -O2 the compiler is permitted to elide an
#        allocation whose result is never read ([expr.new]/10), which deletes
#        the deliberate leak outright and makes valgrind report a clean run.
#        The leak must survive for the profiler to see it, so it is profiled
#        unoptimized. No program logic is changed by either build.
g++ -std=c++17 -g -O2 -o /tmp/mem_cpp     part2/cpp/manual_memory.cpp
g++ -std=c++17 -g -O0 -o /tmp/mem_cpp_dbg part2/cpp/manual_memory.cpp
echo "timing build:    g++ -std=c++17 -g -O2"
echo "profiling build: g++ -std=c++17 -g -O0   (see comment in run_all.sh)"
echo ""
python3 tools/bench.py --label "C++ manual_memory (-O2)" --runs "$RUNS" -- /tmp/mem_cpp

if [ "$TIME_V_OK" = 1 ]; then
  echo "--- /usr/bin/time -v cross-check (C++) ---"
  /usr/bin/time -v /tmp/mem_cpp 2>&1 >/dev/null | grep -E "Maximum resident set size|Elapsed \(wall clock\)"
fi

if [ "$VALGRIND_OK" = 1 ]; then
  echo ""
  echo "--- valgrind clean run ---"
  valgrind --leak-check=full --show-leak-kinds=all /tmp/mem_cpp_dbg >/dev/null 2>/tmp/vg_clean.txt
  grep -E "in use at exit|total heap usage|ERROR SUMMARY" /tmp/vg_clean.txt

  echo ""
  echo "--- valgrind --leak ---"
  valgrind --leak-check=full --show-leak-kinds=all /tmp/mem_cpp_dbg --leak >/dev/null 2>/tmp/vg_leak.txt
  grep -E "in use at exit" /tmp/vg_leak.txt
  grep -A 4 "are definitely lost" /tmp/vg_leak.txt
  grep -E "definitely lost:|indirectly lost:|possibly lost:|ERROR SUMMARY" /tmp/vg_leak.txt

  echo ""
  echo "--- valgrind --dangle ---"
  valgrind --leak-check=full /tmp/mem_cpp_dbg --dangle >/dev/null 2>/tmp/vg_dangle.txt
  grep -A 6 "Invalid read of size" /tmp/vg_dangle.txt | head -12
  grep -E "ERROR SUMMARY" /tmp/vg_dangle.txt
else
  echo ""
  echo "--- valgrind clean run ---   SKIPPED: valgrind not installed on this host"
  echo "--- valgrind --leak ---      SKIPPED: valgrind not installed on this host"
  echo "--- valgrind --dangle ---    SKIPPED: valgrind not installed on this host"
fi

hr "PART 2: Java garbage collection"
# -XX:+UseG1GC is pinned so the GC log does not change with container cpu/memory
# heuristics. Without it the JVM picks Serial on a small container and G1 on a
# larger host, and every GC line in the report moves.
(cd part2/java && javac MemoryDemo.java)
echo "java flags: -XX:+UseG1GC -Xlog:gc -Xmx512m"
echo ""
python3 tools/bench.py --label "Java MemoryDemo (G1)" --runs "$RUNS" --cwd part2/java -- \
    java -XX:+UseG1GC -Xlog:gc -Xmx512m MemoryDemo

hr "PART 2: Rust ownership and borrowing"
rustc -O -o /tmp/mem_rust part2/rust/src/main.rs
python3 tools/bench.py --label "Rust main.rs (-O)" --runs "$RUNS" -- /tmp/mem_rust
echo ""
echo "--- use_after_move.rs (expected to fail) ---"
rustc --out-dir /tmp part2/rust/use_after_move.rs 2>&1 | head -14
echo "--- dangling_ref.rs (expected to fail) ---"
rustc --out-dir /tmp part2/rust/dangling_ref.rs 2>&1 | head -10

hr "END OF RUN"
if [ "$VALGRIND_OK" = 1 ]; then
  echo "valgrind present: this is an authoritative run."
else
  echo "valgrind ABSENT: this log is a secondary artifact, not authoritative."
fi
