# ============================================================================
# C++ Build Workflow
# cmake + ninja + ccache + ctest
# ============================================================================

# Find the active cmake build directory by looking for CMakeCache.txt
_cmake_build_dir() {
  for d in build cmake-build-debug cmake-build-release cmake-build cmake-build-*(N); do
    [[ -f "$d/CMakeCache.txt" ]] && { echo "$d"; return 0 }
  done
  return 1
}

# Configure — preset-aware
# With CMakePresets.json:  cmake-init [preset]   (no arg → lists presets)
# Without:                 cmake-init [build-type] (no arg → Debug)
cmake-init() {
  if [[ -f "CMakePresets.json" ]]; then
    if [[ -z "$1" ]]; then
      echo "📋 Available presets:"
      cmake --list-presets
      return 0
    fi
    cmake --preset "$1"
  else
    cmake -B build -G Ninja -DCMAKE_BUILD_TYPE="${1:-Debug}"
  fi
}

# Configure entire project with ASAN + UBSAN in a separate build dir
cmake-san() {
  cmake -B build-san -G Ninja \
    -DCMAKE_BUILD_TYPE=Debug \
    -DCMAKE_CXX_FLAGS="-fsanitize=address,undefined -fno-omit-frame-pointer" \
    -DCMAKE_EXE_LINKER_FLAGS="-fsanitize=address,undefined"
}

# Build — auto-detects build dir, passes extra args through
# Usage: cb [-- <cmake-build-args>]  e.g. cb -- -j4
cb() {
  local dir
  dir=$(_cmake_build_dir) || { echo "❌ No cmake build dir found. Run cmake-init first."; return 1 }
  cmake --build "$dir" "$@"
}

# Build a specific target
# Usage: cbt <target>
cbt() {
  local dir
  dir=$(_cmake_build_dir) || { echo "❌ No cmake build dir found. Run cmake-init first."; return 1 }
  cmake --build "$dir" --target "${1:?Usage: cbt <target>}"
}

# Run tests — auto-detects build dir, passes extra args through
# Usage: ct [-R <regex>] [-V] etc.
ct() {
  local dir
  dir=$(_cmake_build_dir) || { echo "❌ No cmake build dir found. Run cmake-init first."; return 1 }
  ctest --test-dir "$dir" --output-on-failure "$@"
}

# Symlink compile_commands.json to project root for clangd
ccdb() {
  local dir
  dir=$(_cmake_build_dir) || { echo "❌ No cmake build dir found. Run cmake-init first."; return 1 }
  if [[ ! -f "$dir/compile_commands.json" ]]; then
    echo "❌ No compile_commands.json in $dir"
    echo "💡 Make sure CMAKE_EXPORT_COMPILE_COMMANDS=ON is set"
    return 1
  fi
  ln -sf "$dir/compile_commands.json" .
  echo "✅ Linked $dir/compile_commands.json → ./compile_commands.json"
}
