# FZF-based Interactive Commit
# Usage: gci (git commit interactive)

gci() {
  # Define commit types with descriptions (optimized for data engineering/MLOps)
  local types=(
    # Most common for data engineering
    "data:Data ingestion, cleaning, transformation, validation"
    "pipeline:ETL/ELT pipelines, workflows, orchestration"
    "model:Model training, architecture, hyperparameters, inference"
    "experiment:ML experiments, A/B tests, model comparisons"

    # Infrastructure & deployment
    "deploy:Deployment, infrastructure, K8s, Docker, CI/CD"
    "config:Configuration, environment variables, settings"
    "monitor:Monitoring, logging, alerts, observability"

    # Development essentials
    "feat:New feature or functionality"
    "fix:Bug fix or error resolution"
    "perf:Performance optimization, speed improvements"
    "test:Testing, validation, quality checks"

    # Analysis & visualization
    "analysis:Data analysis, EDA, insights, investigations"
    "viz:Visualizations, dashboards, plots, reports"

    # Code quality
    "refactor:Code restructuring, cleanup, organization"
    "docs:Documentation, README, comments, guides"
    "style:Code formatting, linting, style fixes"
    "chore:Dependencies, build tools, maintenance tasks"
  )

  # Use fzf to select commit type
  local selected_type=$(printf '%s\n' "${types[@]}" | fzf --prompt="Select commit type: " --height=~50% | cut -d: -f1)

  if [ -z "$selected_type" ]; then
    echo "❌ Commit cancelled"
    return 1
  fi

  # Prompt for optional scope
  echo -n "📝 Optional scope (component/dataset/module): "
  read -r scope

  # Prompt for description
  echo -n "📝 Commit message: "
  read -r message

  if [ -z "$message" ]; then
    echo "❌ Commit message required"
    return 1
  fi

  # Format the commit message
  local commit_msg
  if [ -n "$scope" ]; then
    commit_msg="${selected_type}(${scope}): ${message}"
  else
    commit_msg="${selected_type}: ${message}"
  fi

  # Show the formatted message and confirm
  echo ""
  echo "🔍 Commit message:"
  echo "   $commit_msg"
  echo ""
  echo -n "✅ Commit with this message? [Y/n]: "
  read -r confirm

  if [[ $confirm =~ ^[Nn]$ ]]; then
    echo "❌ Commit cancelled"
    return 1
  fi

  git commit -m "$commit_msg"
}

git-project-info() {
  echo "📊 Git + Project Info"
  echo "===================="
  project-info
  echo ""
  echo "🔀 Git Status:"
  git status --short 2>/dev/null || echo "Not a git repository"
  echo ""
  echo "📦 DVC Status:"
  dvc status 2>/dev/null || echo "No DVC repository"
  echo ""
  echo "🌳 Branch Info:"
  git branch -v 2>/dev/null && git remote -v 2>/dev/null || echo "No git remotes"
}
