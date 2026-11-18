#!/usr/bin/env bash
# Re-test what perf can do here without root, row by row, matching the table in
# ../SKILL.md ("Permissions decide what works"). Read-only apart from a temp dir.
set -u

command -v perf >/dev/null || {
  echo "perf is not installed"
  exit 1
}
command -v cc >/dev/null || {
  echo "cc is not installed"
  exit 1
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cd "$tmp" || exit 1

# A short CPU-bound program with a known call chain: main -> mid -> leaf.
cat >chain.c <<'EOF'
volatile long s;
__attribute__((noinline)) void leaf(long n) { for (long i = 0; i < n; i++) s += i; }
__attribute__((noinline)) void mid(void) { leaf(100000000); }
int main(void) { mid(); return 0; }
EOF
cc -O1 -g -fno-omit-frame-pointer chain.c -o chain || exit 1

echo "kernel $(uname -r), $(perf --version)"
echo "perf_event_paranoid=$(cat /proc/sys/kernel/perf_event_paranoid)" \
  "perf_event_mlock_kb=$(cat /proc/sys/kernel/perf_event_mlock_kb)" \
  "ptrace_scope=$(cat /proc/sys/kernel/yama/ptrace_scope 2>/dev/null || echo n/a)"
echo

# row LABEL CMD... : run CMD, print whether it worked.
row() {
  local label=$1 status=0 reason
  shift
  timeout 60 "$@" >/dev/null 2>err.txt || status=$?
  if ((status == 0)); then
    printf '  works  %s\n' "$label"
    return
  fi
  reason=$(grep -v '^Error:$' err.txt | grep -m1 -iE 'failure|error|denied|not supported')
  if [[ -z $reason ]]; then
    reason="exit $status"
    ((status == 124)) && reason="timed out after 60 s"
  fi
  printf '  FAILS  %s  (%s)\n' "$label" "$reason"
}

row "perf stat" perf stat -- ./chain
row "perf record (no -e)" perf record -q -o p.data -- ./chain
row "perf record -e cycles:u" perf record -q -o p.data -e cycles:u -- ./chain
# Both read the recording above. Each must also print what it is for, since
# annotate exits 0 with no output when it cannot disassemble.
row "perf report" bash -c 'perf report -i p.data --stdio >r.txt && grep -q " leaf$" r.txt'
row "perf annotate" bash -c 'perf annotate -i p.data --stdio -s leaf >a.txt && grep -q "<leaf>:" a.txt'
row "-g (no --user-callchains)" perf record -q -o p.data -g -- ./chain
row "--call-graph dwarf (no flag)" perf record -q -o p.data --call-graph dwarf -- ./chain
row "-g --user-callchains" perf record -q -o p.data -g --user-callchains -- ./chain
row "--call-graph dwarf --user-callchains" perf record -q -o p.data --call-graph dwarf --user-callchains -- ./chain
row "--call-graph lbr --user-callchains" perf record -q -o p.data --call-graph lbr --user-callchains -- ./chain
row "system-wide -a" perf record -q -o p.data -a -- sleep 0.2
row "-e ibs_op//" perf record -q -o p.data -e ibs_op// -- ./chain
row "perf c2c record" perf c2c record -o p.data -- ./chain

# Does dwarf unwinding see the middle frame that frame pointers can miss?
if ! perf record -q -o d.data --call-graph dwarf --user-callchains -- ./chain >/dev/null 2>&1; then
  echo "  dwarf stack check not run: its perf record failed"
# Folded output puts each call chain on one line, callee first: leaf;mid;main.
elif ! perf report -i d.data --stdio --no-children -g folded >report.txt 2>/dev/null; then
  echo "  dwarf stack check not run: its perf report failed"
elif grep -qF 'leaf;mid;main' report.txt; then
  echo "  dwarf stacks show leaf -> mid -> main"
else
  echo "  dwarf stacks do NOT show mid"
fi
