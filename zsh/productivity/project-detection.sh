#!/usr/bin/zsh
# Optimized Project Detection with .projectrc + Smart Caching

# Cache variables (session-based)
typeset -A PROJECT_CACHE
typeset -A PROJECT_TYPE_CACHE

# Check if .projectrc exists and is fresh
_is_projectrc_fresh() {
  [[ ! -f ".projectrc" ]] && return 1
  
  # Check if .projectrc is newer than key project files
  local projectrc_time=$(stat -c %Y .projectrc 2>/dev/null || echo 0)
  local key_files=(".project_name" "pyproject.toml" "package.json" "Cargo.toml" "requirements.txt" "dvc.yaml" "MLproject")
  
  for file in "${key_files[@]}"; do
    if [[ -f "$file" ]]; then
      local file_time=$(stat -c %Y "$file" 2>/dev/null || echo 0)
      [[ $file_time -gt $projectrc_time ]] && return 1
    fi
  done
  
  # Check if git info changed
  if [[ -d ".git" ]]; then
    local head_time=$(stat -c %Y .git/HEAD 2>/dev/null || echo 0)
    [[ $head_time -gt $projectrc_time ]] && return 1
  fi
  
  return 0
}

# Load from .projectrc
_load_projectrc() {
  [[ ! -f ".projectrc" ]] && return 1
  
  # Simple key=value format
  local name types
  while IFS='=' read -r key value; do
    case "$key" in
      "PROJECT_NAME") export PROJECTRC_NAME="$value" ;;
      "PROJECT_TYPES") export PROJECTRC_TYPES="$value" ;;
    esac
  done < .projectrc
  
  [[ -n "$PROJECTRC_NAME" && -n "$PROJECTRC_TYPES" ]]
}

# Save to .projectrc
_save_projectrc() {
  local name="$1"
  local types="$2"
  
  cat > .projectrc << EOF
# Auto-generated project configuration
# Delete this file to force re-detection
PROJECT_NAME=$name
PROJECT_TYPES=$types
GENERATED=$(date '+%Y-%m-%d %H:%M:%S')
EOF
  
  echo "💾 Saved project config to .projectrc"
}

# Fast project type detection (optimized)
_detect_project_types_fast() {
  local types=()
  
  # Quick file existence checks (grouped by likelihood)
  local has_python=false has_data=false has_git=false has_jupyter=false
  local has_sql=false has_etl=false has_ml=false has_docker=false
  
  # Group 1: Most common checks first
  [[ -f "requirements.txt" || -f "pyproject.toml" || -f "setup.py" || -f "Pipfile" || -d "venv" || -d ".venv" ]] && has_python=true
  [[ -d ".git" ]] && has_git=true
  [[ -f "Dockerfile" || -f "docker-compose.yml" ]] && has_docker=true
  
  # Group 2: Data-related (batch check)
  if [[ -d "data" || -d "datasets" || -d "notebooks" ]]; then
    [[ -d "data" || -d "datasets" ]] && has_data=true
    [[ -d "notebooks" ]] && has_jupyter=true
  fi
  
  # Group 3: File pattern checks (expensive - do selectively)
  if ! $has_data && ! $has_jupyter; then
    # Only check file patterns if directories weren't found
    [[ -n "$(ls *.csv *.parquet *.json *.pkl 2>/dev/null | head -1)" ]] && has_data=true
    [[ -n "$(ls *.ipynb 2>/dev/null | head -1)" ]] && has_jupyter=true
  fi
  
  # Group 4: Specialized checks (only if we have Python/data context)
  if $has_python || $has_data; then
    [[ -f "MLproject" || -f "mlflow.yml" || -d "mlruns" || -f "train.py" || -f "model.py" ]] && has_ml=true
    [[ -f "dvc.yaml" || -d "dags" || -f "airflow.cfg" || -f "dbt_project.yml" ]] && has_etl=true
  fi
  
  # SQL check
  [[ -d "sql" || -d "queries" || -d "migrations" || -n "$(ls *.sql 2>/dev/null | head -1)" ]] && has_sql=true
  
  # Build results
  $has_python && types+=("python")
  $has_data && types+=("data") 
  $has_jupyter && types+=("jupyter")
  $has_sql && types+=("sql")
  $has_etl && types+=("etl")
  $has_ml && types+=("ml_training")
  $has_docker && types+=("docker")
  $has_git && types+=("git")
  
  printf '%s\n' "${types[@]}"
}

# Optimized get_project_name (same logic, but with caching)
get_project_name() {
  local cache_key="name_$PWD"
  
  # Check session cache first
  if [[ -n "${PROJECT_CACHE[$cache_key]}" ]]; then
    echo "${PROJECT_CACHE[$cache_key]}"
    return
  fi
  
  # Check .projectrc
  if _is_projectrc_fresh && _load_projectrc; then
    PROJECT_CACHE[$cache_key]="$PROJECTRC_NAME"
    echo "$PROJECTRC_NAME"
    return
  fi
  
  # Full detection (same logic as original)
  local dir="$PWD"
  local result=""
  
  # Priority 1: Explicit config
  if [[ -f ".project_name" ]]; then
    result=$(cat .project_name 2>/dev/null | tr -d '\n\r' | tr -d ' ')
    if [[ -n "$result" ]]; then
      PROJECT_CACHE[$cache_key]="$result"
      echo "$result"
      return
    fi
  fi
  
  if [[ -f "pyproject.toml" ]]; then
    result=$(grep -m1 -E "^name\s*=" pyproject.toml 2>/dev/null | sed 's/.*=\s*["\x27]\([^"\x27]*\)["\x27].*/\1/')
    if [[ -n "$result" && "$result" != *"="* ]]; then
      PROJECT_CACHE[$cache_key]="$result"
      echo "$result"
      return
    fi
  fi
  
  # Priority 2: Git info (optimized - single call)
  if [[ -d ".git" ]]; then
    # Get git info in one shot
    local git_info=$(git remote get-url origin 2>/dev/null; echo "---"; git rev-parse --show-toplevel 2>/dev/null)
    local remote_url=$(echo "$git_info" | head -1)
    local git_root=$(echo "$git_info" | tail -1)
    
    if [[ -n "$remote_url" && "$remote_url" != "---" ]]; then
      if [[ "$remote_url" =~ github\.com[:/]([^/]+)/([^/\.]+) ]]; then
        result="${match[2]}"
      elif [[ "$remote_url" =~ gitlab\.com[:/]([^/]+)/([^/\.]+) ]]; then
        result="${match[2]}"
      else
        result=$(basename "$remote_url" .git 2>/dev/null)
      fi
      
      if [[ -n "$result" ]]; then
        PROJECT_CACHE[$cache_key]="$result"
        echo "$result"
        return
      fi
    fi
    
    if [[ -n "$git_root" && "$git_root" != "---" ]]; then
      result=$(basename "$git_root")
      if [[ -n "$result" ]]; then
        PROJECT_CACHE[$cache_key]="$result"
        echo "$result"
        return
      fi
    fi
  fi
  
  # Priority 3: Directory name with filtering
  local dir_name=$(basename "$dir")
  case "$dir_name" in
    "home"|"user"|"src"|"code"|"workspace"|"projects"|"dev"|"work"|"tmp"|"temp"|"Documents"|"Desktop")
      local parent_name=$(basename "$(dirname "$dir")")
      case "$parent_name" in
        "home"|"user"|"src"|"code"|"workspace"|"projects"|"dev"|"work"|"tmp"|"temp"|"Documents"|"Desktop"|"/")
          result="project-$(date +%s | tail -c 4)"
          ;;
        *)
          result="$parent_name"
          ;;
      esac
      ;;
    *)
      result="$dir_name"
      ;;
  esac
  
  PROJECT_CACHE[$cache_key]="$result"
  echo "$result"
}

# Optimized get_project_types 
get_project_types() {
  local cache_key="types_$PWD"
  
  # Check session cache
  if [[ -n "${PROJECT_TYPE_CACHE[$cache_key]}" ]]; then
    echo "${PROJECT_TYPE_CACHE[$cache_key]}"
    return
  fi
  
  # Check .projectrc
  if _is_projectrc_fresh && _load_projectrc; then
    PROJECT_TYPE_CACHE[$cache_key]="$PROJECTRC_TYPES"
    echo "$PROJECTRC_TYPES"
    return
  fi
  
  # Full detection
  local types_array=($(_detect_project_types_fast))
  local types_string="${(j: :)types_array}"  # Join with spaces
  
  PROJECT_TYPE_CACHE[$cache_key]="$types_string"
  echo "$types_string"
}

# Original is_project_type (for compatibility)
is_project_type() {
  local type="$1"
  local all_types=($(get_project_types))
  
  for detected_type in "${all_types[@]}"; do
    [[ "$detected_type" == "$type" ]] && return 0
  done
  return 1
}

# Enhanced project setup command
project-setup() {
  echo "🔍 Analyzing project..."
  
  local name=$(get_project_name)
  local types=($(get_project_types))
  local types_string="${(j: :)types}"
  
  echo "📋 Project: $name"
  echo "🏷️  Types: $types_string"
  
  if [[ ! -f ".projectrc" ]]; then
    echo ""
    echo -n "💾 Save configuration to .projectrc? [Y/n]: "
    read -r reply
    if [[ $reply =~ ^[Yy]$ ]] || [[ -z $reply ]]; then
      _save_projectrc "$name" "$types_string"
      echo "💡 Next time detection will be instant!"
    fi
  else
    echo "✅ Using existing .projectrc (delete to re-detect)"
  fi
  
  echo ""
  echo "🎯 Suggested environment: vc $name"
  [[ " ${types[*]} " =~ " ml_training " ]] && echo "🤖 ML layout: tmux-new (will suggest ML training layout)"
  [[ " ${types[*]} " =~ " etl " ]] && echo "🔧 ETL layout: tmux-new (will suggest ETL layout)"
  [[ " ${types[*]} " =~ " jupyter " ]] && echo "📊 Analysis layout: tmux-new (will suggest analysis layout)"
}

# Cache management
clear-project-cache() {
  PROJECT_CACHE=()
  PROJECT_TYPE_CACHE=()
  echo "🗑️ Project cache cleared"
}

# Quick project info
pinfo() {
  echo "🎯 $(get_project_name)"
  echo "🏷️  $(get_project_types)"
  [[ -f ".projectrc" ]] && echo "💾 Cached in .projectrc" || echo "🔍 Live detection"
}

alias project-info='pinfo'
