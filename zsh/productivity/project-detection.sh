#!/bin/zsh
# =============================================================================
# Simple Project Name Detection for Completions
# =============================================================================

# Simple project name detection with smart priority
get_project_name() {
  local dir="$PWD"
  
  # ==========================================================================
  # PRIORITY 1: EXPLICIT PROJECT CONFIGURATION
  # ==========================================================================
  
  # 1.1 User-defined project name file
  if [[ -f ".project_name" ]]; then
    local name=$(cat .project_name 2>/dev/null | tr -d '\n\r' | tr -d ' ')
    if [[ -n "$name" ]]; then
      echo "$name"
      return
    fi
  fi
  
  # 1.2 Python pyproject.toml
  if [[ -f "pyproject.toml" ]]; then
    local name=$(grep -m1 -E "^name\s*=" pyproject.toml 2>/dev/null | sed 's/.*=\s*["\x27]\([^"\x27]*\)["\x27].*/\1/')
    if [[ -n "$name" && "$name" != *"="* ]]; then
      echo "$name"
      return
    fi
  fi
  
  # 1.3 Node.js package.json
  if [[ -f "package.json" ]]; then
    if command -v jq >/dev/null 2>&1; then
      local name=$(jq -r '.name // empty' package.json 2>/dev/null)
      if [[ -n "$name" && "$name" != "null" ]]; then
        echo "$name"
        return
      fi
    else
      # Fallback without jq
      local name=$(grep -m1 '"name"' package.json 2>/dev/null | sed 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
      if [[ -n "$name" ]]; then
        echo "$name"
        return
      fi
    fi
  fi
  
  # 1.4 Rust Cargo.toml
  if [[ -f "Cargo.toml" ]]; then
    local name=$(grep -m1 -E "^name\s*=" Cargo.toml 2>/dev/null | sed 's/.*=\s*["\x27]\([^"\x27]*\)["\x27].*/\1/')
    if [[ -n "$name" && "$name" != *"="* ]]; then
      echo "$name"
      return
    fi
  fi
  
  # ==========================================================================
  # PRIORITY 2: GIT REPOSITORY INFORMATION
  # ==========================================================================
  
  if git rev-parse --git-dir >/dev/null 2>&1; then
    # 2.1 Git remote origin URL (extract repo name)
    local remote_url=$(git remote get-url origin 2>/dev/null)
    if [[ -n "$remote_url" ]]; then
      local repo_name=""
      
      # GitHub/GitLab/Bitbucket URL patterns
      if [[ "$remote_url" =~ github\.com[:/]([^/]+)/([^/\.]+) ]]; then
        repo_name="${match[2]}"  # zsh match array
      elif [[ "$remote_url" =~ gitlab\.com[:/]([^/]+)/([^/\.]+) ]]; then
        repo_name="${match[2]}"
      elif [[ "$remote_url" =~ bitbucket\.org[:/]([^/]+)/([^/\.]+) ]]; then
        repo_name="${match[2]}"
      else
        # Generic git URL: extract last part and remove .git
        repo_name=$(basename "$remote_url" .git 2>/dev/null)
      fi
      
      if [[ -n "$repo_name" && "$repo_name" != "." ]]; then
        echo "$repo_name"
        return
      fi
    fi
    
    # 2.2 Git root directory name (fallback)
    local git_root=$(git rev-parse --show-toplevel 2>/dev/null)
    if [[ -n "$git_root" ]]; then
      local git_name=$(basename "$git_root")
      if [[ -n "$git_name" ]]; then
        echo "$git_name"
        return
      fi
    fi
  fi
  
  # ==========================================================================
  # PRIORITY 3: DIRECTORY NAME (with smart filtering)
  # ==========================================================================
  
  local dir_name=$(basename "$dir")
  
  # Filter out generic/unhelpful directory names
  case "$dir_name" in
    "home"|"user"|"src"|"code"|"workspace"|"projects"|"dev"|"work"|"tmp"|"temp"|"Documents"|"Desktop")
      # For generic names, try parent directory if it looks more meaningful
      local parent_name=$(basename "$(dirname "$dir")")
      case "$parent_name" in
        "home"|"user"|"src"|"code"|"workspace"|"projects"|"dev"|"work"|"tmp"|"temp"|"Documents"|"Desktop"|"/")
          echo "project-$(date +%s | tail -c 4)"  # Generate a unique fallback
          ;;
        *)
          echo "$parent_name"
          ;;
      esac
      ;;
    *)
      echo "$dir_name"
      ;;
  esac
}

# =============================================================================
# HELPER FUNCTIONS FOR COMPLETIONS
# =============================================================================

# Check if we're in a specific type of project (for context-aware completions)
is_project_type() {
  local type="$1"
  case "$type" in
    "python")
      [[ -f "requirements.txt" || -f "pyproject.toml" || -f "setup.py" || -f "Pipfile" || -d "venv" || -d ".venv" ]]
      ;;
    "data")
      [[ -d "data" || -d "datasets" || -f *.csv(N) || -f *.parquet(N) || -f *.json(N) ]]
      ;;
    "jupyter")
      [[ -d "notebooks" || -f *.ipynb(N) ]]
      ;;
    "git")
      git rev-parse --git-dir >/dev/null 2>&1
      ;;
    "node")
      [[ -f "package.json" || -f "package-lock.json" || -f "yarn.lock" ]]
      ;;
    "rust")
      [[ -f "Cargo.toml" ]]
      ;;
    "docker")
      [[ -f "Dockerfile" || -f "docker-compose.yml" || -f "docker-compose.yaml" ]]
      ;;
    *)
      return 1
      ;;
  esac
}

# =============================================================================
# TEST FUNCTION
# =============================================================================

# Test the project detection
test_project_detection() {
  echo "🔍 Project Name Detection Test"
  echo "=============================="
  echo "📁 Current directory: $PWD"
  echo ""
  
  local project_name=$(get_project_name)
  echo "📋 Detected name: $project_name"
  echo ""
  
  echo "📄 Detection details:"
  
  # Show what files/config were found
  [[ -f ".project_name" ]] && echo "  ✅ .project_name: $(cat .project_name 2>/dev/null)"
  [[ -f "pyproject.toml" ]] && echo "  ✅ pyproject.toml found"
  [[ -f "package.json" ]] && echo "  ✅ package.json found"
  [[ -f "Cargo.toml" ]] && echo "  ✅ Cargo.toml found"
  
  if is_project_type "git"; then
    echo "  ✅ Git repository"
    local remote_url=$(git remote get-url origin 2>/dev/null)
    [[ -n "$remote_url" ]] && echo "    📡 Remote: $remote_url"
    local git_root=$(git rev-parse --show-toplevel 2>/dev/null)
    [[ -n "$git_root" ]] && echo "    📁 Git root: $(basename "$git_root")"
  else
    echo "  ❌ Not a git repository"
  fi
  
  echo ""
  echo "🏷️  Project types detected:"
  is_project_type "python" && echo "  ✅ Python project"
  is_project_type "data" && echo "  ✅ Data project"
  is_project_type "jupyter" && echo "  ✅ Jupyter project"
  is_project_type "node" && echo "  ✅ Node.js project"
  is_project_type "rust" && echo "  ✅ Rust project"
  is_project_type "docker" && echo "  ✅ Docker project"
  
  echo ""
  echo "💡 For vc completion, would suggest: $project_name"
}

# Alias for easy testing
alias pdt='test_project_detection'
