# llama.cpp-vulkan — patched PKGBUILD (durable backup)

Backup of the locally-patched [`llama.cpp-vulkan`](https://aur.archlinux.org/packages/llama.cpp-vulkan)
AUR PKGBUILD. The **primary** mechanism is still paru's `SaveChanges` (the patch
lives as a git commit in `~/.cache/paru/clone/llama.cpp-vulkan` and is rebased onto
each upstream version bump). This copy exists so the patch survives a paru cache
wipe or a fresh machine — it is **not** wired into `install.sh`.

## The patch (`no-webui.patch`)

Builds `llama-server`/`llama-cli` with **no web UI**: no npm build, no Hugging Face
prebuilt-asset download, no network access during build.

- `-DLLAMA_BUILD_UI=OFF` — skip the npm source build
- `-DLLAMA_USE_PREBUILT_UI=OFF` — skip the HF prebuilt-UI download
- drops `nodejs`/`npm` makedeps, removes the dead Tailwind `.git` hack from `prepare()`
- `-DGGML_RPC=OFF`, removed inert `-DGGML_CUDA_FA_ALL_QUANTS`

> ⚠️ Upstream renamed these flags once already (`LLAMA_BUILD_WEBUI` → `LLAMA_BUILD_UI`
> at ~b9616), which silently broke the build. If a future bump fails, check
> `tools/ui/CMakeLists.txt` in the new source for renamed UI flags.

## Recovery / standalone build

If `SaveChanges` is lost, build directly from this dir (all sources are remote URLs,
so no extra files are needed):

```bash
cd dotfiles/aur/llama.cpp-vulkan
updpkgsums            # refresh sha256sums after bumping pkgver
makepkg -si           # or: paru -Ui ./
```

To re-seed the paru `SaveChanges` clone instead, drop this PKGBUILD over
`~/.cache/paru/clone/llama.cpp-vulkan/PKGBUILD` and `git commit` it there.

## Keeping this copy current

This is a backup, not the source of truth — refresh it after a successful update:

```bash
cp ~/.cache/paru/clone/llama.cpp-vulkan/PKGBUILD dotfiles/aur/llama.cpp-vulkan/PKGBUILD
git -C ~/.cache/paru/clone/llama.cpp-vulkan show HEAD -- PKGBUILD \
  > dotfiles/aur/llama.cpp-vulkan/no-webui.patch
```
