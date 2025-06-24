#!/usr/bin/zsh
# Enhanced get_project_name with selected bonus patterns
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
  # PRIORITY 2: STRUCTURAL PATTERNS (NEW)
  # ==========================================================================

  # 2.1 Date-based project folders (YYYY-MM-DD pattern)
  local current_folder=$(basename "$dir")
  if [[ "$current_folder" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2} ]]; then
    local parent_name=$(basename "$(dirname "$dir")")
    case "$parent_name" in
      "home" | "user" | "Documents" | "Desktop" | "/")
        echo "$current_folder"
        ;;
      *)
        echo "$parent_name-$current_folder"
        ;;
    esac
    return
  fi

  # 2.2 Monorepo detection
  if [[ -f "lerna.json" || -f "nx.json" || -f "rush.json" || -f "pnpm-workspace.yaml" ]]; then
    local repo_name=$(basename "$dir")
    echo "$repo_name"
    return
  fi

  # ==========================================================================
  # PRIORITY 3: GIT REPOSITORY INFORMATION
  # ==========================================================================

  if git rev-parse --git-dir >/dev/null 2>&1; then
    # 3.1 Git remote origin URL (extract repo name)
    local remote_url=$(git remote get-url origin 2>/dev/null)
    if [[ -n "$remote_url" ]]; then
      local repo_name=""

      # GitHub/GitLab/Bitbucket URL patterns
      if [[ "$remote_url" =~ github\.com[:/]([^/]+)/([^/\.]+) ]]; then
        repo_name="${match[2]}" # zsh match array
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

    # 3.2 Git root directory name (fallback)
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
  # PRIORITY 4: DIRECTORY NAME (with smart filtering)
  # ==========================================================================

  local dir_name=$(basename "$dir")

  # Filter out generic/unhelpful directory names
  case "$dir_name" in
    "home" | "user" | "src" | "code" | "workspace" | "projects" | "dev" | "work" | "tmp" | "temp" | "Documents" | "Desktop")
      # For generic names, try parent directory if it looks more meaningful
      local parent_name=$(basename "$(dirname "$dir")")
      case "$parent_name" in
        "home" | "user" | "src" | "code" | "workspace" | "projects" | "dev" | "work" | "tmp" | "temp" | "Documents" | "Desktop" | "/")
          echo "project-$(date +%s | tail -c 4)" # Generate a unique fallback
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

# Check if we're in a specific type of project
is_project_type() {
  local type="$1"
  case "$type" in
    "python")
      [[ -f "requirements.txt" || -f "pyproject.toml" || -f "setup.py" || -f "Pipfile" || 
         -f "environment.yml" || -f "conda.yml" || -d "venv" || -d ".venv" || -d "env" ||
         -f "poetry.lock" || -f "pipenv.lock" ]]
      ;;
    "data")
      [[ -d "data" || -d "datasets" || -d "raw" || -d "processed" || -d "external" ||
         -f *.csv(N) || -f *.parquet(N) || -f *.json(N) || -f *.jsonl(N) || 
         -f *.avro(N) || -f *.orc(N) || -f *.feather(N) || -f *.xlsx(N) || 
         -f *.pkl(N) || -f *.pickle(N) || -f *.h5(N) || -f *.hdf5(N) ]]
      ;;
    "jupyter")
      [[ -d "notebooks" || -f *.ipynb(N) || -d ".ipynb_checkpoints" ]]
      ;;
    "git")
      git rev-parse --git-dir >/dev/null 2>&1
      ;;
    "node")
      [[ -f "package.json" || -f "package-lock.json" || -f "yarn.lock" || -f "pnpm-lock.yaml" ]]
      ;;
    "rust")
      [[ -f "Cargo.toml" || -f "Cargo.lock" ]]
      ;;
    "docker")
      [[ -f "Dockerfile" || -f "docker-compose.yml" || -f "docker-compose.yaml" || 
         -f ".dockerignore" || -d ".docker" ]]
      ;;
    "sql")
      [[ -f *.sql(N) || -d "sql" || -d "queries" || -d "migrations" || -d "schemas" ||
         -f "schema.sql" || -f "init.sql" || -f "seed.sql" || -d "db" ||
         -f "alembic.ini" || -d "alembic" || -f "flyway.conf" || -d "flyway" ||
         -f *.ddl(N) || -f *.dml(N) ]]
      ;;
    "etl")
      [[ -d "dags" || -f "airflow.cfg" || -d "airflow" ||
         -f "dbt_project.yml" || -d "models" || -d "macros" || -d "tests" ||
         -f "kafka.properties" || -f "server.properties" || -d "kafka" ||
         -f "beam_pipeline.py" || -f "spark_job.py" || -d "pipelines" ||
         -f "prefect.yaml" || -f "dagster.yaml" || -d "etl" || -d "pipeline" ||
         -f "luigi.cfg" || -f "kedro.yml" || -d "conf" ||
         -f *.scala(N) && -d "src/main/scala" ]]
      ;;
    "ml_training")
      [[ -f "MLproject" || -f "mlflow.yml" || -d "mlruns" || -d "models" ||
         -f *.pt(N) || -f *.pth(N) || -f *.h5(N) || -f *.onnx(N) ||
         -f *.pkl(N) && -d "models" || -f *.joblib(N) ||
         -f "config.yaml" && -d "experiments" || -d "checkpoints" ||
         -f "wandb.yaml" || -d "wandb" || -f ".wandb" ||
         -f "tensorboard" || -d "logs" && -d "models" ||
         -f "params.yaml" || -f "metrics.yaml" || -f "dvc.yaml" ||
         -f "hyperparams.yml" || -d "hyperparameters" ||
         -f "train.py" || -f "training.py" || -f "model.py" ||
         -f "requirements.txt" && ( -f "*train*.py"(N) || -f "*model*.py"(N) ) ]]
      ;;
    "scala")
      [[ -f "build.sbt" || -f "project/build.properties" || -d "src/main/scala" ||
         -f "pom.xml" && -d "src/main/scala" ]]
      ;;
    "go")
      [[ -f "go.mod" || -f "go.sum" || -f "main.go" || -d "cmd" ]]
      ;;
    "c_cpp")
      [[ -f "Makefile" || -f "CMakeLists.txt" || -f "configure.ac" ||
         -f *.c(N) || -f *.cpp(N) || -f *.h(N) || -f *.hpp(N) ]]
      ;;
    "web")
      [[ -f "index.html" || -f "app.js" || -d "public" || -d "static" ||
         -f "webpack.config.js" || -f "vite.config.js" || -f "next.config.js" ]]
      ;;
    "config")
      [[ -f *.yaml(N) || -f *.yml(N) || -f *.toml(N) || -f *.ini(N) ||
         -f *.conf(N) || -f *.env(N) || -f "config.json" ]]
      ;;
    *)
      return 1
      ;;
  esac
}

# Helper function to get all detected project types
get_project_types() {
  local types=()
  local all_types=("python" "data" "jupyter" "sql" "etl" "ml_training" "scala" "node" "rust" "go" "c_cpp" "docker" "web" "config" "git")
  
  for type in "${all_types[@]}"; do
    if is_project_type "$type"; then
      types+=("$type")
    fi
  done
  
  printf '%s\n' "${types[@]}"
}

# Enhanced test function to show the new patterns
test_project_detection() {
  echo "🔍 Enhanced Project Name Detection Test"
  echo "======================================="
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

  # Show structural patterns (NEW)
  local current_folder=$(basename "$PWD")
  [[ "$current_folder" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2} ]] && echo "  ✅ Date-based folder detected"
  [[ -f "lerna.json" || -f "nx.json" || -f "rush.json" || -f "pnpm-workspace.yaml" ]] && echo "  ✅ Monorepo detected"

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
