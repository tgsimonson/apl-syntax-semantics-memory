#!/usr/bin/env python3
"""Run a memory program repeatedly and report timing spread and peak RSS.

Single-run timings on a laptop are not defensible, so each program is run
`--runs` times. Two independent timings are recorded per run:

  in-program  the program's own "elapsed: N ms" line, which measures only the
              allocation loop and excludes process/JVM startup. This is the
              figure the report compares across languages.
  wall        the full process lifetime measured by the harness, which for Java
              includes JVM startup and is therefore not comparable to C++/Rust.

Peak RSS is measured with /usr/bin/time -v when GNU time is available, and
falls back to getrusage(2) on the child via wait4 when it is not (macOS ships
BSD time, which has no -v).

The fallback is genuinely a fallback, not an equal alternative. On Linux the
child inherits this interpreter's resident pages across fork(), and the kernel
does not reset the RSS high-water mark on execve, so ru_maxrss reads back as
max(program peak, python peak) -- roughly an 8 MB floor that silently swamps
any program smaller than that. macOS does reset the mark, so the fallback is
accurate there. Which method produced a figure is printed with it.
"""
import os
import re
import statistics
import subprocess
import sys
import tempfile
import time

GNU_TIME = "/usr/bin/time"
RSS_RE = re.compile(r"Maximum resident set size \(kbytes\):\s*(\d+)")


def gnu_time_works():
    """True if /usr/bin/time supports -v (GNU time, not BSD time)."""
    try:
        p = subprocess.run(
            [GNU_TIME, "-v", "true"], capture_output=True, timeout=10
        )
    except (OSError, subprocess.SubprocessError):
        return False
    return b"Maximum resident set size" in p.stderr

ELAPSED_RE = re.compile(r"^elapsed:\s*(\d+)\s*ms", re.MULTILINE)


def maxrss_to_mb(maxrss):
    # linux reports ru_maxrss in kilobytes, darwin in bytes
    if sys.platform == "darwin":
        return maxrss / (1024.0 * 1024.0)
    return maxrss / 1024.0


def run_once(cmd, cwd=None, use_gnu_time=False):
    """fork/exec the command, capture its output, and measure peak RSS."""
    rss_file = None
    if use_gnu_time:
        fd, rss_file = tempfile.mkstemp(prefix="bench_rss_")
        os.close(fd)
        cmd = [GNU_TIME, "-v", "-o", rss_file] + list(cmd)

    read_fd, write_fd = os.pipe()
    t0 = time.monotonic()
    pid = os.fork()
    if pid == 0:
        try:
            os.close(read_fd)
            os.dup2(write_fd, 1)
            os.dup2(write_fd, 2)
            if write_fd > 2:
                os.close(write_fd)
            if cwd:
                os.chdir(cwd)
            os.execvp(cmd[0], cmd)
        except Exception:
            pass
        os._exit(127)

    os.close(write_fd)
    chunks = []
    with os.fdopen(read_fd, "rb") as pipe:
        while True:
            buf = pipe.read(65536)
            if not buf:
                break
            chunks.append(buf)
    _, status, ru = os.wait4(pid, 0)
    wall_ms = (time.monotonic() - t0) * 1000.0
    out = b"".join(chunks).decode("utf-8", "replace")

    rss_mb = None
    if rss_file:
        try:
            with open(rss_file) as fh:
                m = RSS_RE.search(fh.read())
            if m:
                rss_mb = int(m.group(1)) / 1024.0
        except OSError:
            pass
        finally:
            try:
                os.unlink(rss_file)
            except OSError:
                pass
    if rss_mb is None:
        rss_mb = maxrss_to_mb(ru.ru_maxrss)

    return {
        "out": out,
        "status": status,
        "wall_ms": wall_ms,
        "rss_mb": rss_mb,
    }


def fmt_range(values, unit, prec=0):
    lo, hi = min(values), max(values)
    med = statistics.median(values)
    return "median {m:.{p}f} {u}   range {lo:.{p}f}-{hi:.{p}f} {u}".format(
        m=med, lo=lo, hi=hi, u=unit, p=prec
    )


def main(argv):
    label = "benchmark"
    runs = 5
    cwd = None
    show_output = True

    args = argv[1:]
    while args and args[0].startswith("--"):
        flag = args.pop(0)
        if flag == "--label":
            label = args.pop(0)
        elif flag == "--runs":
            runs = int(args.pop(0))
        elif flag == "--cwd":
            cwd = args.pop(0)
        elif flag == "--quiet":
            show_output = False
        elif flag == "--":
            break
        else:
            sys.stderr.write("bench.py: unknown flag %s\n" % flag)
            return 2
    cmd = args
    if not cmd:
        sys.stderr.write("bench.py: no command given\n")
        return 2

    use_gnu_time = gnu_time_works()
    rss_method = "/usr/bin/time -v" if use_gnu_time else "getrusage(2) fallback"

    results = []
    for _ in range(runs):
        results.append(run_once(cmd, cwd, use_gnu_time))

    failed = [r for r in results if r["status"] != 0]

    if show_output:
        print("--- output of run 1 of %d ---" % runs)
        print(results[0]["out"].rstrip("\n"))

    print("--- %s: %d runs ---" % (label, runs))

    in_prog = []
    for r in results:
        m = ELAPSED_RE.search(r["out"])
        if m:
            in_prog.append(int(m.group(1)))

    for i, r in enumerate(results, 1):
        m = ELAPSED_RE.search(r["out"])
        got = "%s ms" % m.group(1) if m else "n/a"
        print(
            "  run %d:  in-program %-7s wall %7.1f ms   peak RSS %6.1f MB"
            % (i, got, r["wall_ms"], r["rss_mb"])
        )

    if in_prog:
        print("  in-program elapsed:  %s" % fmt_range(in_prog, "ms"))
    else:
        print("  in-program elapsed:  not reported by this program")
    print("  wall clock:          %s" % fmt_range([r["wall_ms"] for r in results], "ms", 1))
    rss = [r["rss_mb"] for r in results]
    print(
        "  peak RSS:            %s   (max %.1f MB)   via %s"
        % (fmt_range(rss, "MB", 1), max(rss), rss_method)
    )

    if failed:
        print("  WARNING: %d of %d runs exited non-zero" % (len(failed), runs))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
