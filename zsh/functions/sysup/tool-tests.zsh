# Invoked only by `sysup --test-tools`. The projects' own uv.lock pins their test
# runs to known-good versions, so a breaking dependency release would only show up
# in the installed tool. Each suite runs here in a throwaway environment resolved
# to the newest allowed versions (--isolated --upgrade): the lockfile, the project's
# .venv and the installed uv tool are never touched. A failure is recorded in the
# caller's _sysup_notes (zsh dynamic scope) and does not stop sysup.
# The projects directory is an argument so tests can drive this without the real ones.
_sysup_tool_tests() {
  local root=${1:-"$HOME/projects"}
  local -a projects=(
    "mathunicode"
    "paper-refinery --extra dev"
    "audio_text"
  )
  local entry name out rc summary line
  local -a words lines broken=() unrun=()
  for entry in $projects; do
    words=(${=entry})
    name=$words[1]
    if [[ ! -f $root/$name/pyproject.toml ]]; then
      echo "    $name: no checkout at $root/$name — skipping"
      continue
    fi
    # stdin from /dev/null: a test that prompts must fail, not hang the update.
    out=$(cd "$root/$name" && UV_COMPILE_BYTECODE=0 PYTHONDONTWRITEBYTECODE=1 \
      timeout 600 uv run --isolated --upgrade ${words[2,-1]} \
      python -m pytest -q -p no:cacheprovider 2>&1 </dev/null)
    rc=$?
    lines=(${(f)out})
    summary=
    for line in ${(Oa)lines}; do # last pytest summary line; uv may print warnings after it
      if [[ $line =~ '(passed|failed|skipped|error|no tests ran).* in [0-9.]+s' ]]; then
        summary=$line
        break
      fi
    done
    if (( rc == 124 )); then
      echo "    $name: TIMED OUT after 600 s"
      unrun+=($name)
    elif (( rc == 0 )); then
      echo "    $name: ${summary:-ran, no pytest summary}"
    elif [[ -z $summary ]]; then
      echo "    $name: could not run the suite (exit $rc) — resolving, network or build?"
      (( ${#lines} )) && print -r -- "${(F)lines[-15,-1]}"
      unrun+=($name)
    else
      echo "    $name: FAILED with the latest dependencies (exit $rc): $summary"
      print -r -- "${(F)lines[-40,-1]}"
      broken+=($name)
    fi
  done
  (( ${#broken} )) && _sysup_notes+=("tests failed with the latest dependencies: ${(j:, :)broken}; the installed tools may be broken, see the output above")
  (( ${#unrun} )) && _sysup_notes+=("tests could not run (timed out, or resolving/network/build failed): ${(j:, :)unrun}; see the output above")
  (( ! ${#broken} && ! ${#unrun} ))
}
