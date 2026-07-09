# papis-ask: run `papis ask` against a local llama.cpp embedding server.
# Qwen3-Embedding-4B (Q8) is served over llama-server's OpenAI-compatible API.

PAPIS_ASK_EMBED_MODEL="Qwen/Qwen3-Embedding-4B-GGUF:Q8_0"
PAPIS_ASK_EMBED_PORT=8088
PAPIS_ASK_EMBED_LOG="${XDG_CACHE_HOME:-$HOME/.cache}/papis-ask-embed.log"

_papis_ask_embed_up() {
  curl -sf -m 2 "http://127.0.0.1:${PAPIS_ASK_EMBED_PORT}/health" 2>/dev/null | grep -q '"ok"'
}

# Something answers on the port (HTTP reply of any status) — i.e. a server is
# already there, possibly still loading the model (/health returns 503 then).
_papis_ask_embed_port_busy() {
  curl -s -o /dev/null -m 2 "http://127.0.0.1:${PAPIS_ASK_EMBED_PORT}/health" 2>/dev/null
}

_papis_ask_ensure_embed() {
  _papis_ask_embed_up && return 0
  if _papis_ask_embed_port_busy; then
    # A server owns the port but isn't ready yet — wait for it instead of
    # launching a duplicate that would fail to bind.
    echo "papis-ask: embedding server already starting on port ${PAPIS_ASK_EMBED_PORT}, waiting…" >&2
  else
    echo "papis-ask: starting embedding server (${PAPIS_ASK_EMBED_MODEL})…" >&2
    nohup llama-server -hf "$PAPIS_ASK_EMBED_MODEL" \
      --embeddings --pooling last -ngl 99 \
      --port "$PAPIS_ASK_EMBED_PORT" >"$PAPIS_ASK_EMBED_LOG" 2>&1 &!
  fi
  local i
  for i in {1..150}; do
    _papis_ask_embed_up && { echo "papis-ask: embedding server ready." >&2; return 0; }
    sleep 2
  done
  echo "papis-ask: server failed to come up — see $PAPIS_ASK_EMBED_LOG" >&2
  return 1
}

# paper-refinery: pre-chunk PDFs with `refinery`/`refinery-batch` so `papis ask
# index` has <pdf>.chunks.json to read. papis-ask itself never calls refinery
# (it's a pure file consumer, per docs/paper-refinery-integration.md) -- this is
# the "run refinery first" step, kept here so `pask index` stays one command.

_papis_ask_needs_refine() {
  local pdf="$1" chunks="${1%.pdf}.chunks.json"
  [[ ! -f "$chunks" || "$pdf" -nt "$chunks" ]]
}

# papis' own query language has no OR (docmatcher.py ANDs every space-separated
# term/key:value pair together) and `papis ask index` takes exactly one query
# argument -- so "match paper A OR paper B" can't be expressed in one papis
# call at all. _papis_ask_refine_pending and pask's index branch both accept
# multiple query strings and union/loop across them instead.

_papis_ask_matching_pdfs() {
  local query="$1"
  # papis list --all -f "" matches zero documents (unlike omitting the query
  # entirely, which matches all) -- so the arg must be dropped, not empty.
  if [[ -n "$query" ]]; then
    papis list --all -f "$query" 2>/dev/null | grep -i '\.pdf$'
  else
    papis list --all -f 2>/dev/null | grep -i '\.pdf$'
  fi
}

# Refine (single `refinery` or, for more than one PDF, `refinery-batch`)
# whichever PDFs matching any of $queries lack fresh chunks.json (deduped
# union across queries). No-op if all current.
_papis_ask_refine_pending() {
  local -a queries=("$@")
  (( ${#queries} )) || queries=("")
  local -A seen
  local -a pdfs pending
  local q p
  for q in "${queries[@]}"; do
    for p in "${(@f)$(_papis_ask_matching_pdfs "$q")}"; do
      [[ -n "$p" && -z "${seen[$p]}" ]] && { seen[$p]=1; pdfs+=("$p") }
    done
  done
  (( ${#pdfs} )) || return 0
  for p in "${pdfs[@]}"; do
    _papis_ask_needs_refine "$p" && pending+=("$p")
  done
  (( ${#pending} )) || return 0
  echo "papis-ask: refining ${#pending} PDF(s) before indexing…" >&2
  if (( ${#pending} == 1 )); then
    refinery "${pending[1]}"
  else
    refinery-batch "${pending[@]}"
  fi
}

# Ensure the embedding server is up (only if the local embedding model is
# configured), auto-refine pending PDFs matching any given queries, then run
# papis ask index. Without --force the index call is always unscoped, since
# papis_ask's own incremental check makes that a cheap no-op for every paper
# the query didn't touch. --force is different: it bypasses that check, so
# dropping the query there would silently force-reindex the *entire*
# library instead of just what matched -- so --force keeps the query,
# looping per query when there's more than one (each pass only touches its
# own match; papis_ask's deletion check is whole-library-aware so this can't
# delete anything out of scope, see the papis-ask deletion-scope fix).
pask() {
  ( source ~/.config/secrets/papis.env 2>/dev/null
    if [[ "$(papis config ask.embedding 2>/dev/null)" == openai/* ]]; then
      _papis_ask_ensure_embed || exit 1
    fi

    if [[ "$1" == "index" ]]; then
      local -a rest=("${@:2}") flags=() queries=()
      local a is_force=0
      for a in "${rest[@]}"; do
        if [[ "$a" == -* ]]; then
          flags+=("$a")
          [[ "$a" == "-f" || "$a" == "--force" ]] && is_force=1
        else
          queries+=("$a")
        fi
      done

      if [[ "${flags[*]}" != *--no-refine* && "${flags[*]}" != *--raw* ]]; then
        _papis_ask_refine_pending "${queries[@]}"
      fi

      if (( is_force )) && (( ${#queries} )); then
        local q
        for q in "${queries[@]}"; do
          papis ask index "${flags[@]}" "$q"
        done
      else
        papis ask index "${flags[@]}"
      fi
    else
      papis ask "$@"
    fi
  )
}

# Stop the warm embedding server when you're done (frees ~4 GB).
paskstop() {
  pkill -f "llama-server.*${PAPIS_ASK_EMBED_PORT}" \
    && echo "papis-ask: embedding server stopped." \
    || echo "papis-ask: no embedding server running."
}
