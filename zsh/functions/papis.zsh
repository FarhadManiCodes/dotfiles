# papis-ask: run `papis ask` against a local llama.cpp embedding server.
# Qwen3-Embedding-4B (Q8) is served over llama-server's OpenAI-compatible API;
# paper-qa reaches it via LiteLLM's openai/ provider (OPENAI_API_BASE in papis/secrets).

PAPIS_ASK_EMBED_MODEL="Qwen/Qwen3-Embedding-4B-GGUF:Q8_0"
PAPIS_ASK_EMBED_PORT=8088
PAPIS_ASK_EMBED_LOG="${XDG_CACHE_HOME:-$HOME/.cache}/papis-ask-embed.log"

_papis_ask_embed_up() {
  curl -sf -m 2 "http://127.0.0.1:${PAPIS_ASK_EMBED_PORT}/health" 2>/dev/null | grep -q '"ok"'
}

_papis_ask_ensure_embed() {
  _papis_ask_embed_up && return 0
  echo "papis-ask: starting embedding server (${PAPIS_ASK_EMBED_MODEL})…" >&2
  nohup llama-server -hf "$PAPIS_ASK_EMBED_MODEL" \
    --embeddings --pooling last -ngl 99 \
    --port "$PAPIS_ASK_EMBED_PORT" >"$PAPIS_ASK_EMBED_LOG" 2>&1 &!
  local i
  for i in {1..150}; do
    _papis_ask_embed_up && { echo "papis-ask: embedding server ready." >&2; return 0; }
    sleep 2
  done
  echo "papis-ask: server failed to come up — see $PAPIS_ASK_EMBED_LOG" >&2
  return 1
}

# Ensure the embedding server is up, then run papis ask (works for `pask index` too).
pask() {
  ( source ~/.config/papis/secrets 2>/dev/null
    _papis_ask_ensure_embed && papis ask "$@" )
}

# Stop the warm embedding server when you're done (frees ~4 GB).
paskstop() {
  pkill -f "llama-server.*${PAPIS_ASK_EMBED_PORT}" \
    && echo "papis-ask: embedding server stopped." \
    || echo "papis-ask: no embedding server running."
}
