# Invoked only by `sysup --test-tools`. The projects' own uv.lock pins their test
# runs to known-good versions, so a breaking dependency release would only show up
# in the installed tool. Each suite runs here in a throwaway environment resolved
# to the newest allowed versions (--isolated --upgrade): the lockfile, the project's
# .venv and the installed uv tool are never touched. A failure is recorded in the
# caller's _sysup_notes (zsh dynamic scope) and does not stop sysup.
# The projects directory is an argument so tests can drive this without the real ones.
_sysup_tool_tests() {
  local outfile
  outfile=$(mktemp "${XDG_RUNTIME_DIR:-/tmp}/sysup-tool-tests.XXXXXX") || return 1
  # always: also removed when a Ctrl-C trap returns out of the middle of a run
  { _sysup_tool_tests_run "$outfile" "$@" } always { rm -f -- "$outfile" }
}

_sysup_tool_tests_run() {
  local outfile=$1 root=${2:-"$HOME/projects"}
  local -a projects=(
    "mathunicode"
    "paper-refinery --extra dev"
    "audio_text"
  )
  local entry name rc summary line n
  local -a words lines broken=() unrun=()
  for entry in $projects; do
    words=(${=entry})
    name=$words[1]
    if [[ ! -f $root/$name/pyproject.toml ]]; then
      echo "    $name: no checkout at $root/$name — skipping"
      continue
    fi
    # stdin from /dev/null: a test that prompts must fail, not hang the update.
    # Output goes to a file, not through $(...): a suite's leftover grandchild would hold a
    # pipe open past the timeout and block this step until it exits.
    ( cd "$root/$name" && PYTHONDONTWRITEBYTECODE=1 \
      timeout --foreground 600 uv run --isolated --upgrade --no-compile-bytecode ${words[2,-1]} \
      python -m pytest -q -p no:cacheprovider >"$outfile" 2>&1 </dev/null )
    rc=$?
    lines=(${(f)"$(<$outfile)"})
    summary=
    for line in ${(Oa)lines}; do # last pytest summary line; uv may print warnings after it
      if [[ $line =~ '(passed|failed|skipped|error|no tests ran).* in [0-9.]+s' ]]; then
        summary=$line
        break
      fi
    done
    if _sysup_interrupted $rc; then # Ctrl-C or TERM, not a result
      echo "    $name: interrupted"
      _sysup_notes+=("tool tests interrupted at $name")
      return "$rc"
    elif (( rc == 124 )); then
      echo "    $name: TIMED OUT after 600 s"
      unrun+=($name)
    elif (( rc == 0 )); then
      echo "    $name: ${summary:-ran, no pytest summary}"
    elif [[ -z $summary || $rc == (4|5) ]]; then # 4, 5: pytest usage error, nothing collected
      echo "    $name: could not run the suite (exit $rc) — nothing collected, or uv could not resolve, fetch or build"
      n=$(( ${#lines} > 15 ? -15 : 1 ))
      (( ${#lines} )) && print -r -- "${(F)lines[n,-1]}"
      unrun+=($name)
    else
      echo "    $name: FAILED with the latest dependencies (exit $rc): $summary"
      n=$(( ${#lines} > 40 ? -40 : 1 ))
      print -r -- "${(F)lines[n,-1]}"
      broken+=($name)
    fi
  done
  (( ${#broken} )) && _sysup_notes+=("tests failed with the latest dependencies: ${(j:, :)broken}; the installed tools may be broken, see the output above")
  (( ${#unrun} )) && _sysup_notes+=("tests could not run (timed out, nothing collected, or resolve/network/build failed): ${(j:, :)unrun}; see the output above")
  (( ! ${#broken} && ! ${#unrun} ))
}
