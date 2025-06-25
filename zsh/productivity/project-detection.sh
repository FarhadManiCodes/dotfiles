#!/usr/bin/zsh
# Git-aware Project Detection (works from any subdirectory)
#
# Project Root Priority System:
# 1. .projectrc file (searches current + 2 levels up)
# 2. Git repository root 
# 3. Current directory
#

# Get the project root directory (priority: .projectrc > git root > current directory)
_get_project_root() {
  # Priority 1: Look for existing .projectrc in current directory or up to 2 levels up
  local current_dir="$PWD"
  local level=0
  while [[ "$current_dir" != "/" && $level -le 2 ]]; do
    if [[ -f "$current_dir/.projectrc" ]]; then
      echo "$current_dir"
      return
    fi
    current_dir=$(dirname "$current_dir")
    level=$((level + 1))
  done
  
  # Priority 2: Git root if in git repository
  if git rev-parse --git-dir >/dev/null 2>&1; then
    local git_root=$(git rev-parse --show-toplevel 2>/dev/null)
    if [[ -n "$git_root" ]]; then
      echo "$git_root"
      return
    fi
  fi
  
  # Priority 3: Current directory as fallback
  echo "$PWD"
}

# Check if .projectrc exists in project root and is fresh
_is_projectrc_fresh() {
  local project_root=$(_get_project_root)
  local projectrc_file="$project_root/.projectrc"
  
  [[ ! -f "$projectrc_file" ]] && return 1
  
  # Check if .projectrc is newer than key project files
  local projectrc_time
  if command -v stat >/dev/null 2>&1; then
    if stat -c %Y "$projectrc_file" >/dev/null 2>&1; then
      projectrc_time=$(stat -c %Y "$projectrc_file" 2>/dev/null)
    elif stat -f %m "$projectrc_file" >/dev/null 2>&1; then
      projectrc_time=$(stat -f %m "$projectrc_file" 2>/dev/null)
    else
      return 1
    fi
  else
    return 1
  fi
  
  [[ -z "$projectrc_time" ]] && return 1
  
  # Check key files in project root
  local key_files=(".project_name" "pyproject.toml" "package.json" "requirements.txt" "dvc.yaml" "MLproject")
  
  for file in "${key_files[@]}"; do
    local full_path="$project_root/$file"
    if [[ -f "$full_path" ]]; then
      local file_time
      if stat -c %Y "$full_path" >/dev/null 2>&1; then
        file_time=$(stat -c %Y "$full_path" 2>/dev/null)
      elif stat -f %m "$full_path" >/dev/null 2>&1; then
        file_time=$(stat -f %m "$full_path" 2>/dev/null)
      else
        continue
      fi
      
      if [[ -n "$file_time" && "$file_time" -gt "$projectrc_time" ]]; then
        return 1
      fi
    fi
  done
  
  # Check if git HEAD changed (for git repos)
  if git rev-parse --git-dir >/dev/null 2>&1; then
    local git_head="$project_root/.git/HEAD"
    if [[ -f "$git_head" ]]; then
      local head_time
      if stat -c %Y "$git_head" >/dev/null 2>&1; then
        head_time=$(stat -c %Y "$git_head" 2>/dev/null)
      elif stat -f %m "$git_head" >/dev/null 2>&1; then
        head_time=$(stat -f %m "$git_head" 2>/dev/null)
      fi
      
      if [[ -n "$head_time" && "$head_time" -gt "$projectrc_time" ]]; then
        return 1
      fi
    fi
  fi
  
  return 0
}

# Detect project layout based on priority system (for project-detection.sh)
_detect_project_layout() {
  local detected_types=($(get_project_types 2>/dev/null))
  [[ $? -ne 0 ]] && return 1

  # Convert to associative lookup for faster checking
  local -A type_map
  for type in "${detected_types[@]}"; do
    type_map[$type]=1
  done

  # Priority-based layout selection (exact order as specified)
  
  # 1. 🤖 ML Training (highest priority)
  if [[ -n "${type_map[ml_training]}" ]]; then
    echo "ml_training"
    return 0
  fi
  
  # 2. 🔧 ETL/Data Engineering  
  if [[ -n "${type_map[etl]}" ]]; then
    echo "etl"
    return 0
  fi
  
  # 3. 📊 Data Science (jupyter + data combination)
  if [[ -n "${type_map[jupyter]}" && -n "${type_map[data]}" ]]; then
    echo "analysis"
    return 0
  fi
  
  # 4. 🗄️ SQL/Database
  if [[ -n "${type_map[sql]}" ]]; then
    echo "database"
    return 0
  fi
  
  # 5. 🐍 Python (includes python + data combinations)
  if [[ -n "${type_map[python]}" ]]; then
    echo "developer"
    return 0
  fi
  
  # 6. 🐳 Docker
  if [[ -n "${type_map[docker]}" ]]; then
    echo "docker"
    return 0
  fi
  
  # 7. 🌳 Git (lowest priority)
  if [[ -n "${type_map[git]}" ]]; then
    echo "git"
    return 0
  fi
  
  # Fallback to basic if no specific type detected
  echo "basic"
}

# Load from .projectrc in project root
_load_projectrc() {
  local project_root=$(_get_project_root)
  local projectrc_file="$project_root/.projectrc"
  
  [[ ! -f "$projectrc_file" ]] && return 1
  
  # Simple key=value format
  unset PROJECTRC_NAME PROJECTRC_TYPES PROJECTRC_LAYOUT
  while IFS='=' read -r key value || [[ -n "$key" ]]; do
    # Skip comments and empty lines
    [[ "$key" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$key" ]] && continue
    
    case "$key" in
      "PROJECT_NAME") 
        PROJECTRC_NAME="$value"
        ;;
      "PROJECT_TYPES") 
        PROJECTRC_TYPES="$value"
        ;;
      "PROJECT_LAYOUT")
        PROJECTRC_LAYOUT="$value"
        ;;
    esac
  done < "$projectrc_file"
  
  [[ -n "$PROJECTRC_NAME" && -n "$PROJECTRC_TYPES" ]]
}

# Save to .projectrc in project root
_save_projectrc() {
  local name="$1"
  local types="$2"
  local layout="$3"
  local project_root=$(_get_project_root)
  local projectrc_file="$project_root/.projectrc"
  
  cat > "$projectrc_file" << EOF
# Auto-generated project configuration
# This file defines the project root boundary
# Delete this file to force re-detection
PROJECT_NAME=$name
PROJECT_TYPES=$types
PROJECT_LAYOUT=$layout
GENERATED=$(date '+%Y-%m-%d %H:%M:%S')
DETECTED_FROM=$PWD
EOF
  
  echo "💾 Saved project config to $projectrc_file"
  
  # Show relative path if we're in a subdirectory
  if [[ "$PWD" != "$project_root" ]]; then
    local relative_path=$(realpath --relative-to="$PWD" "$projectrc_file" 2>/dev/null || echo "$projectrc_file")
    echo "📁 From current location: $relative_path"
  fi
  
  echo "💡 This .projectrc now defines your project boundary and caches layout: $layout"
}


# Fast project type detection (git-aware)
_detect_project_types_fast() {
  local types=()
  local project_root=$(_get_project_root)
  
  # Always check if we're in git first
  if git rev-parse --git-dir >/dev/null 2>&1; then
    types+=("git")
  fi
  
  # Python detection (check project root)
  if [[ -f "$project_root/requirements.txt" || -f "$project_root/pyproject.toml" || -f "$project_root/setup.py" || -f "$project_root/Pipfile" || -d "$project_root/venv" || -d "$project_root/.venv" ]]; then
    types+=("python")
  fi
  
  # Data detection (check both root and common data subdirectories)
  local data_found=false
  if [[ -d "$project_root/data" || -d "$project_root/datasets" || -d "$project_root/raw" || -d "$project_root/processed" ]]; then
    data_found=true
  else
    # Check for data files in project root
    if [[ -n "$(find "$project_root" -maxdepth 1 -name "*.csv" -o -name "*.parquet" -o -name "*.json" -o -name "*.pkl" 2>/dev/null | head -1)" ]]; then
      data_found=true
    fi
  fi
  $data_found && types+=("data")
  
  # Jupyter detection
  local jupyter_found=false
  if [[ -d "$project_root/notebooks" ]]; then
    jupyter_found=true
  else
    # Check for notebooks in project root
    if [[ -n "$(find "$project_root" -maxdepth 1 -name "*.ipynb" 2>/dev/null | head -1)" ]]; then
      jupyter_found=true
    fi
  fi
  $jupyter_found && types+=("jupyter")
  
  # Docker detection
  [[ -f "$project_root/Dockerfile" || -f "$project_root/docker-compose.yml" || -f "$project_root/docker-compose.yaml" ]] && types+=("docker")
  
  # SQL detection
  local sql_found=false
  if [[ -d "$project_root/sql" || -d "$project_root/queries" || -d "$project_root/migrations" ]]; then
    sql_found=true
  else
    if [[ -n "$(find "$project_root" -maxdepth 1 -name "*.sql" 2>/dev/null | head -1)" ]]; then
      sql_found=true
    fi
  fi
  $sql_found && types+=("sql")
  
  # ETL detection
  if [[ -f "$project_root/dvc.yaml" || -d "$project_root/dags" || -f "$project_root/airflow.cfg" || -f "$project_root/dbt_project.yml" ]]; then
    types+=("etl")
  fi
  
  # ML Training detection
  if [[ -f "$project_root/MLproject" || -f "$project_root/mlflow.yml" || -d "$project_root/mlruns" || -f "$project_root/train.py" || -f "$project_root/model.py" ]]; then
    types+=("ml_training")
  fi
  
  printf '%s\n' "${types[@]}"
}

# Git-aware get_project_name
get_project_name() {
  local project_root=$(_get_project_root)
  
  # Check .projectrc first
  if _is_projectrc_fresh && _load_projectrc; then
    echo "$PROJECTRC_NAME"
    return
  fi
  
  # Priority 1: Explicit config in project root
  if [[ -f "$project_root/.project_name" ]]; then
    local result=$(cat "$project_root/.project_name" 2>/dev/null | tr -d '\n\r' | tr -d ' ')
    if [[ -n "$result" ]]; then
      echo "$result"
      return
    fi
  fi
  
  if [[ -f "$project_root/pyproject.toml" ]]; then
    local result=$(grep -m1 -E "^name\s*=" "$project_root/pyproject.toml" 2>/dev/null | sed 's/.*=\s*["\x27]\([^"\x27]*\)["\x27].*/\1/')
    if [[ -n "$result" && "$result" != *"="* ]]; then
      echo "$result"
      return
    fi
  fi
  
  if [[ -f "$project_root/package.json" ]]; then
    if command -v jq >/dev/null 2>&1; then
      local result=$(jq -r '.name // empty' "$project_root/package.json" 2>/dev/null)
      if [[ -n "$result" && "$result" != "null" ]]; then
        echo "$result"
        return
      fi
    fi
  fi
  
  # Priority 2: Git info (if we're in a git repo)
  if git rev-parse --git-dir >/dev/null 2>&1; then
    local remote_url=$(git remote get-url origin 2>/dev/null)
    if [[ -n "$remote_url" ]]; then
      local result=""
      if [[ "$remote_url" =~ github\.com[:/]([^/]+)/([^/\.]+) ]]; then
        result="${match[2]}"
      elif [[ "$remote_url" =~ gitlab\.com[:/]([^/]+)/([^/\.]+) ]]; then
        result="${match[2]}"
      else
        result=$(basename "$remote_url" .git 2>/dev/null)
      fi
      
      if [[ -n "$result" ]]; then
        echo "$result"
        return
      fi
    fi
    
    # Use git root directory name
    local result=$(basename "$project_root")
    if [[ -n "$result" ]]; then
      echo "$result"
      return
    fi
  fi
  
  # Priority 3: Project root directory name with filtering
  local dir_name=$(basename "$project_root")
  case "$dir_name" in
    "home"|"user"|"src"|"code"|"workspace"|"projects"|"dev"|"work"|"tmp"|"temp"|"Documents"|"Desktop")
      local parent_name=$(basename "$(dirname "$project_root")")
      case "$parent_name" in
        "home"|"user"|"src"|"code"|"workspace"|"projects"|"dev"|"work"|"tmp"|"temp"|"Documents"|"Desktop"|"/")
          echo "project-$(date +%s | tail -c 4)"
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

# Git-aware get_project_types
get_project_types() {
  # Check .projectrc first
  if _is_projectrc_fresh && _load_projectrc; then
    echo "$PROJECTRC_TYPES"
    return
  fi
  
  # Full detection
  local types_array=($(_detect_project_types_fast))
  local types_string="${(j: :)types_array}"  # Join with spaces
  
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

# Enhanced project setup command (with 2-level priority system)
project-setup() {
  local project_root=$(_get_project_root)
  local current_location=""
  
  if [[ "$PWD" != "$project_root" ]]; then
    current_location=" (from $(basename "$PWD"))"
  fi
  
  echo "🔍 Analyzing project$current_location..."
  
  # Show how project root was determined (limited to 2 levels)
  echo "🎯 Project root: $project_root"
  local current_dir="$PWD"
  local found_projectrc=false
  local level=0
  while [[ "$current_dir" != "/" && $level -le 2 ]]; do
    if [[ -f "$current_dir/.projectrc" ]]; then
      echo "   📍 Found existing .projectrc in: $current_dir (level $level)"
      found_projectrc=true
      break
    fi
    current_dir=$(dirname "$current_dir")
    level=$((level + 1))
  done
  
  if [[ "$found_projectrc" == "false" ]]; then
    if git rev-parse --git-dir >/dev/null 2>&1; then
      echo "   📍 Using git repository root"
    else
      echo "   📍 Using current directory (no .projectrc within 2 levels or git found)"
    fi
  fi
  
  local name=$(get_project_name)
  local types=($(get_project_types))
  local types_string="${(j: :)types}"
  local layout=$(_detect_project_layout)  # Detect layout for caching
  
  echo ""
  echo "📋 Project: $name"
  echo "🏷️  Types: $types_string"
  echo "🎨 Layout: $layout"
  
  # Show layout meaning with emoji
  case "$layout" in
    "ml_training") echo "   🤖 ML Training - Machine Learning projects" ;;
    "etl") echo "   🔧 ETL/Data Engineering - Data pipelines and ETL" ;;
    "analysis") echo "   📊 Data Science - Jupyter notebooks and data analysis" ;;
    "database") echo "   🗄️ Database - SQL projects and databases" ;;
    "developer") echo "   🐍 Python - General Python development" ;;
    "docker") echo "   🐳 Docker - Containerized applications" ;;
    "git") echo "   🌳 Git - Version control repositories" ;;
    "basic") echo "   📁 Basic - Standard terminal layout" ;;
  esac
  
  if [[ ! -f "$project_root/.projectrc" ]]; then
    echo ""
    echo -n "💾 Save configuration to .projectrc in project root? [Y/n]: "
    read -r reply
    if [[ $reply =~ ^[Yy]$ ]] || [[ -z $reply ]]; then
      _save_projectrc "$name" "$types_string" "$layout"
      echo "💡 Next time detection will be instant from anywhere in the project!"
      echo "💡 .projectrc now defines the project boundary (searchable up to 2 levels)"
      echo "💡 Layout ($layout) is cached for consistent tmux sessions"
    fi
  else
    echo "✅ Using existing .projectrc in project root"
    
    # Check if layout is missing and update if needed
    if _load_projectrc 2>/dev/null && [[ -z "$PROJECTRC_LAYOUT" ]]; then
      echo ""
      echo "🔄 Updating .projectrc with layout cache..."
      _save_projectrc "$PROJECTRC_NAME" "$PROJECTRC_TYPES" "$layout"
      echo "💡 Layout ($layout) added to existing configuration"
    elif _load_projectrc 2>/dev/null && [[ "$PROJECTRC_LAYOUT" != "$layout" ]]; then
      echo ""
      echo "⚠️  Cached layout ($PROJECTRC_LAYOUT) differs from detected layout ($layout)"
      echo -n "🔄 Update cached layout to current detection? [Y/n]: "
      read -r reply
      if [[ $reply =~ ^[Yy]$ ]] || [[ -z $reply ]]; then
        _save_projectrc "$PROJECTRC_NAME" "$PROJECTRC_TYPES" "$layout"
        echo "💡 Layout cache updated to: $layout"
      else
        echo "💡 Keeping cached layout: $PROJECTRC_LAYOUT"
      fi
    fi
    
    if [[ "$PWD" != "$project_root" ]]; then
      echo "📍 Config location: $(realpath --relative-to="$PWD" "$project_root/.projectrc" 2>/dev/null || echo "$project_root/.projectrc")"
    fi
  fi
  
  echo ""
  echo "🎯 Suggested environment: vc $name"
  
  # Show layout-specific suggestions
  case "$layout" in
    "ml_training") 
      echo "🤖 ML Training layout: Auto-starts with specialized ML environment"
      echo "   • GPU monitoring • Training logs • Model checkpoints • Experiments"
      ;;
    "etl") 
      echo "🔧 ETL layout: Auto-starts with data engineering tools"
      echo "   • Pipeline monitoring • Data quality • Logs • Orchestration"
      ;;
    "analysis") 
      echo "📊 Data Science layout: Auto-starts with analysis environment"
      echo "   • Jupyter server • Data exploration • Visualization • Research"
      ;;
    "database") 
      echo "🗄️ Database layout: Auto-starts with database tools"
      echo "   • SQL client • Query optimization • Schema management • Monitoring"
      ;;
    "developer") 
      echo "🐍 Python layout: Auto-starts with development environment"
      echo "   • Code editor • Testing • Debugging • Virtual environment"
      ;;
    "docker") 
      echo "🐳 Docker layout: Auto-starts with container management"
      echo "   • Container monitoring • Logs • Build process • Services"
      ;;
    "git") 
      echo "🌳 Git layout: Auto-starts with version control tools"
      echo "   • Git status • Interactive staging • Branch management • History"
      ;;
    "basic")
      echo "📁 Basic layout: Standard terminal environment"
      echo "   • Single window • General purpose • No specialized tools"
      ;;
  esac
  
  echo ""
  echo "💡 Next terminal session will auto-start tmux with $layout layout"
}

# Quick project info (git-aware)
pinfo() {
  local project_root=$(_get_project_root)
  local current_info=""
  
  if [[ "$PWD" != "$project_root" ]]; then
    current_info=" (from $(basename "$PWD"))"
  fi
  
  echo "🎯 $(get_project_name)$current_info"
  echo "🏷️  $(get_project_types)"
  echo "📁 Root: $project_root"
  
  if [[ -f "$project_root/.projectrc" ]]; then
    if _load_projectrc 2>/dev/null && [[ -n "$PROJECTRC_LAYOUT" ]]; then
      echo "🎨 Layout: $PROJECTRC_LAYOUT (cached)"
    else
      echo "🎨 Layout: $(_detect_project_layout) (live)"
    fi
    echo "💾 Cached in .projectrc"
  else
    echo "🎨 Layout: $(_detect_project_layout) (live)"
    echo "🔍 Live detection"
  fi
}

# Test function
test_project_detection() {
  local project_root=$(_get_project_root)
  
  echo "🔍 Git-Aware Project Detection Test"
  echo "==================================="
  echo "📁 Current directory: $PWD"
  echo "📁 Project root: $project_root"
  echo ""
  
  # Show how project root was determined (limited to 2 levels)
  echo "🎯 Project root determined by:"
  local current_dir="$PWD"
  local found_projectrc=false
  local level=0
  while [[ "$current_dir" != "/" && $level -le 2 ]]; do
    if [[ -f "$current_dir/.projectrc" ]]; then
      echo "   ✅ Found .projectrc in: $current_dir (level $level)"
      found_projectrc=true
      break
    fi
    current_dir=$(dirname "$current_dir")
    level=$((level + 1))
  done
  
  if [[ "$found_projectrc" == "false" ]]; then
    if git rev-parse --git-dir >/dev/null 2>&1; then
      echo "   ✅ Git repository root: $(git rev-parse --show-toplevel 2>/dev/null)"
    else
      echo "   ✅ Current directory (no .projectrc or git found)"
    fi
  fi
  
  echo ""
  echo "📋 Name: $(get_project_name)"
  echo "🏷️  Types: $(get_project_types)"
  
  # Show both cached and live layout
  local live_layout=$(_detect_project_layout)
  echo "🎨 Layout (live): $live_layout"
  
  if [[ -f "$project_root/.projectrc" ]] && _load_projectrc 2>/dev/null && [[ -n "$PROJECTRC_LAYOUT" ]]; then
    echo "🎨 Layout (cached): $PROJECTRC_LAYOUT"
    if [[ "$PROJECTRC_LAYOUT" != "$live_layout" ]]; then
      echo "⚠️  Cached and live layouts differ!"
    fi
  fi
  
  echo ""
  
  if git rev-parse --git-dir >/dev/null 2>&1; then
    echo "🌳 Git repository: ✅"
    echo "   Remote: $(git remote get-url origin 2>/dev/null || echo "No remote")"
    echo "   Branch: $(git branch --show-current 2>/dev/null || echo "Unknown")"
  else
    echo "🌳 Git repository: ❌"
  fi
  
  echo ""
  echo "🔧 Detected features:"
  local types=($(get_project_types))
  for type in "${types[@]}"; do
    case "$type" in
      "python") echo "  🐍 Python project" ;;
      "data") echo "  📊 Data project" ;;
      "jupyter") echo "  📓 Jupyter project" ;;
      "sql") echo "  🗃️ SQL project" ;;
      "etl") echo "  🔄 ETL project" ;;
      "ml_training") echo "  🤖 ML Training project" ;;
      "docker") echo "  🐳 Docker project" ;;
      "git") echo "  🌳 Git repository" ;;
    esac
  done
  
  echo ""
  echo "🎯 Layout Priority System:"
  echo "  1. 🤖 ML Training → ml_training_layout.sh"
  echo "  2. 🔧 ETL/Data Engineering → etl_layout.sh"
  echo "  3. 📊 Data Science → analysis_layout.sh"
  echo "  4. 🗄️ SQL/Database → database_layout.sh"
  echo "  5. 🐍 Python → developer_layout.sh"
  echo "  6. 🐳 Docker → docker_layout.sh"
  echo "  7. 🌳 Git → git_layout.sh"
  
  if [[ -f "$project_root/.projectrc" ]]; then
    echo ""
    echo "💾 .projectrc found at: $project_root/.projectrc"
    if _load_projectrc 2>/dev/null; then
      echo "   Name: $PROJECTRC_NAME"
      echo "   Types: $PROJECTRC_TYPES"
      if [[ -n "$PROJECTRC_LAYOUT" ]]; then
        echo "   Layout: $PROJECTRC_LAYOUT (cached)"
      else
        echo "   Layout: Not cached (run project-setup to update)"
      fi
    fi
  else
    echo ""
    echo "💡 Run 'project-setup' to create .projectrc with layout caching"
  fi
}
alias project-info='pinfo'
alias project-test='test_project_detection'

# Utility function to show project root detection logic
project-root() {
  echo "🔍 Project Root Detection Priority (2 levels max):"
  echo "================================================="
  
  # Check for .projectrc walking up (limited to 2 levels)
  local current_dir="$PWD"
  local level=0
  echo ""
  echo "1️⃣ Looking for .projectrc (current + 2 levels up):"
  while [[ "$current_dir" != "/" && $level -le 2 ]]; do
    if [[ -f "$current_dir/.projectrc" ]]; then
      echo "   ✅ Found: $current_dir/.projectrc (level $level)"
      echo "   🎯 Project root: $current_dir"
      return
    else
      echo "   ❌ Not found: $current_dir/.projectrc (level $level)"
    fi
    current_dir=$(dirname "$current_dir")
    level=$((level + 1))
  done
  
  echo ""
  echo "2️⃣ Checking git repository:"
  if git rev-parse --git-dir >/dev/null 2>&1; then
    local git_root=$(git rev-parse --show-toplevel 2>/dev/null)
    echo "   ✅ Found git root: $git_root"
    echo "   🎯 Project root: $git_root"
  else
    echo "   ❌ Not in git repository"
    echo ""
    echo "3️⃣ Using current directory:"
    echo "   🎯 Project root: $PWD"
  fi
}
