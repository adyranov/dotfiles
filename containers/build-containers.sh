#!/usr/bin/env bash
set -euo pipefail

# Configuration
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT_DIR
readonly CONTAINERS_DIR="${ROOT_DIR}/containers"
readonly TEST_CMD="/home/devcontainer/.local/bin/check-dotfiles"
readonly BUILDKITD_CONFIG="${HOME}/.config/docker/buildkitd/buildkitd.toml"

# Utility functions
log() { echo "$1" >&2; }
log_error() { log "❌ $1"; }
log_info() { log "ℹ️ $1"; }
log_success() { log "✅ $1"; }
get_name() { basename "$1"; }

# Suggest parallel installation
suggest_parallel() {
  log_info "GNU parallel not found. Install for faster builds:"
  case "$(uname -s)" in
    Darwin) log "  brew install parallel" ;;
    Linux)
      if command -v apt-get >/dev/null 2>&1; then log "  sudo apt-get install parallel"
      elif command -v pacman >/dev/null 2>&1; then log "  sudo pacman -S parallel"
      else log "  Visit: https://www.gnu.org/software/parallel/"
      fi ;;
  esac
  log_info "Continuing with sequential builds..."
}

# Generate unique builder name
get_builder_name() {
  local container_name="$1"
  echo "buildx_buildkit_${container_name}_$(date +%s)_$(shuf -i 1000-9999 -n 1)"
}

# Create BuildKit builder
create_builder() {
  local builder_name="$1"
  local container_name="$2"
  local buildkitd_args=()

  if [ -f "${BUILDKITD_CONFIG}" ]; then
    log_info "[${container_name}] Using buildkitd config: ${BUILDKITD_CONFIG}"
    buildkitd_args+=("--config" "${BUILDKITD_CONFIG}")
  else
    log_info "[${container_name}] No buildkitd config found, using defaults"
  fi

  docker buildx create \
    --name "$builder_name" \
    --driver docker-container \
    --driver-opt image=moby/buildkit:buildx-stable-1 \
    "${buildkitd_args[@]}" \
    --use || return 1

  docker buildx inspect "$builder_name" --bootstrap || return 1
}

# Clean up specific builder
cleanup_builder() {
  local builder_name="$1"
  docker buildx rm -f "$builder_name" 2>/dev/null || true
}

# Usage
usage() {
  cat << EOF
Usage: $0 [OPTIONS] [CONTAINER_NAMES...]

Build and test Docker containers.

OPTIONS:
  -h, --help                    Show this help message
  -l, --list                    List available containers and exit
  -c, --config CONFIG_PATH      Use custom buildkitd config file
                                (default: ~/.config/docker/buildkitd/buildkitd.toml)

EXAMPLES:
  $0                                    # Build all containers
  $0 archlinux                          # Build only archlinux container
  $0 --list                             # List available containers
  $0 --config /path/to/buildkitd.toml   # Use custom buildkitd config

EOF
}

# Discover and list containers
discover_containers() {
  find "${CONTAINERS_DIR}" -mindepth 1 -maxdepth 1 -type d -exec test -f '{}/Dockerfile' \; -print | sort
}

# Display containers
display_containers() {
  local containers=("$@")
  log "📦 Available containers:"
  for container in "${containers[@]}"; do
    log "  - $(get_name "$container")"
  done
}

# Filter containers by selection
filter_containers() {
  local all_containers=("$@")
  local filtered=()

  if [ ${#SELECTED_CONTAINERS[@]} -eq 0 ]; then
    filtered=("${all_containers[@]}")
  else
    for selected in "${SELECTED_CONTAINERS[@]}"; do
      local found=false
      for container in "${all_containers[@]}"; do
        if [ "$(get_name "$container")" = "$selected" ]; then
          filtered+=("$container")
          found=true
          break
        fi
      done
      if [ "$found" = false ]; then
        log_error "Container '$selected' not found"
        display_containers "${all_containers[@]}"
        exit 1
      fi
    done
  fi
  printf '%s\n' "${filtered[@]}"
}

# Parse arguments
SELECTED_CONTAINERS=()
LIST_ONLY=false

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help) usage; exit 0 ;;
    -l|--list) LIST_ONLY=true; shift ;;
    -c|--config)
      if [ -z "${2:-}" ]; then
        log_error "Option $1 requires an argument"
        usage
        exit 1
      fi
      BUILDKITD_CONFIG="$2"
      shift 2
      ;;
    -*) log_error "Unknown option: $1"; usage; exit 1 ;;
    *) SELECTED_CONTAINERS+=("$1"); shift ;;
  esac
done

# Build and run container
run_container() {
  local dir="$1"
  local name
  local tag
  local builder_name
  name="$(basename "$dir")"
  tag="dotfiles-${name}"
  builder_name="$(get_builder_name "$name")"

  log "🐳 [${name}] build start"

  if ! create_builder "$builder_name" "$name"; then
    log_error "[${name}] failed to create builder"
    exit 1
  fi

  # Build with optional GitHub token
  local build_args=(
    --builder "$builder_name"
    --no-cache
    --progress=plain
    --load
    -t "${tag}"
    -f "${dir}/Dockerfile"
  )

  if [ -n "${GITHUB_TOKEN:-}" ]; then
    printf '%s' "${GITHUB_TOKEN}" | docker buildx build "${build_args[@]}" --secret id=GITHUB_TOKEN,src=/dev/stdin "${ROOT_DIR}"
  else
    docker buildx build "${build_args[@]}" "${ROOT_DIR}"
  fi || {
    log_error "[${name}] build failed"
    cleanup_builder "$builder_name"
    exit 1
  }

  cleanup_builder "$builder_name"

  log "🚀 [${name}] run start"
  docker run --rm -w "${HOME}" "${tag}" "${TEST_CMD}" || { log_error "[${name}] test failed"; exit 1; }
  log_success "[${name}] done"
}

# Wrapper for parallel execution with clean output
run_container_parallel() {
  local container_path="$1"
  local container_name
  container_name="$(basename "$container_path")"
  run_container "$container_path" 2>&1 | while IFS= read -r line; do
    echo "[${container_name}] ${line}"
  done
}

run_containers() {
  local containers=("$@")
  if command -v parallel >/dev/null 2>&1; then
    log_info "Using GNU parallel for concurrent builds..."
    parallel --halt soon,fail=1 --line-buffer run_container_parallel ::: "${containers[@]}"
  else
    suggest_parallel
    log_info "Running sequentially..."
    for container in "${containers[@]}"; do
      run_container "$container"
    done
  fi
}

# Main execution
main() {
  docker info >/dev/null || { log_error "Docker unavailable"; exit 1; }

  local all_containers
  mapfile -t all_containers < <(discover_containers)
  [ ${#all_containers[@]} -eq 0 ] && { log_error "No containers found"; exit 1; }

  if [ "$LIST_ONLY" = true ]; then
    display_containers "${all_containers[@]}"
    exit 0
  fi

  local containers
  mapfile -t containers < <(filter_containers "${all_containers[@]}")

  log "🔍 Building ${#containers[@]} container(s):"
  for container in "${containers[@]}"; do
    log "  - $(get_name "$container")"
  done

  export -f run_container run_container_parallel get_name get_builder_name create_builder cleanup_builder log log_info log_success log_error
  export ROOT_DIR TEST_CMD BUILDKITD_CONFIG

  run_containers "${containers[@]}"
  log_success "All containers tested successfully!"
}

main
