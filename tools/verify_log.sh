#!/usr/bin/env bash
# Checks a captured log against the acceptance criteria for this assignment.
# usage: tools/verify_log.sh logs/full_run_linux.txt
set -u
LOG="${1:-logs/full_run_linux.txt}"
[ -r "$LOG" ] || { echo "verify: cannot read $LOG" >&2; exit 2; }

pass=0; fail=0
ok(){   printf '  [ PASS ] %s\n' "$1"; pass=$((pass+1)); }
no(){   printf '  [ FAIL ] %s\n' "$1"; fail=$((fail+1)); }
check(){ if grep -qE "$2" "$LOG"; then ok "$1"; else no "$1"; fi; }

echo "acceptance criteria: $LOG"

check "toolchain versions printed at top" '^valgrind: +valgrind-[0-9]'
check "valgrind clean run: 0 bytes in 0 blocks in use at exit" \
      'in use at exit: 0 bytes in 0 blocks'
check "valgrind --leak: 1,024,000 bytes in 1,000 blocks definitely lost" \
      '1,024,000 bytes in 1,000 blocks are definitely lost'
check "valgrind --leak: attributed to a manual_memory.cpp source line" \
      'manual_memory\.cpp:[0-9]+'
check "valgrind --dangle: Invalid read of size 4" 'Invalid read of size 4'
check "valgrind --dangle: address is inside a block that was free'd" \
      "bytes inside a block of size [0-9]+ free'd"
check "rustc rejects use_after_move.rs with E0382" 'error\[E0382\]'
check "rustc rejects dangling_ref.rs with E0106"   'error\[E0106\]'

# five timing runs and a peak RSS figure for each of the three memory programs
runs5=$(grep -c '^  run 5:' "$LOG")
rssn=$(grep -c '^  peak RSS:' "$LOG")
[ "$runs5" -ge 3 ] && ok "five timing runs for all three memory programs (found $runs5)" \
                   || no "five timing runs for all three memory programs (found $runs5, want 3)"
[ "$rssn" -ge 3 ] && ok "peak RSS reported for all three memory programs (found $rssn)" \
                  || no "peak RSS reported for all three memory programs (found $rssn, want 3)"

# java: a full gc that reclaims nothing while the list is retained, then a
# later full gc that drops the heap sharply once it is cleared.
gc=$(awk '
  /Pause Full/ && match($0, /[0-9]+M->[0-9]+M/) {
    s = substr($0, RSTART, RLENGTH); split(s, a, "M->"); b = a[1] + 0; e = a[2] + 0
    if (b >= 10 && e >= 0.9 * b) { retained = 1 }
    if (retained && b >= 10 && e <= 0.3 * b) { dropped = 1 }
  }
  END { print (retained ? "R" : "-") (dropped ? "D" : "-") }
' "$LOG")
case "$gc" in
  RD) ok "java GC: full collection reclaims nothing while retained, then drops after clear" ;;
  R-) no "java GC: retention seen, but no later collection dropping the heap" ;;
  *)  no "java GC: no full collection showing retention (looked for NNM->NNM)" ;;
esac

echo ""
echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
