#!/usr/bin/env bash
set -euo pipefail

# Configuration
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT_DIR
readonly CONTAINERS_DIR="${ROOT_DIR}/containers"
readonly DEFAULT_BUILDKITD_CONFIG="${HOME}/.config/docker/buildkitd/buildkitd.toml"
BUILDKITD_CONFIG="${DEFAULT_BUILDKITD_CONFIG}"

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
      if command -v apt-get >/dev/null 2>&1; then
        log "  sudo apt-get install parallel"
      elif command -v dnf >/dev/null 2>&1; then
        log "  sudo dnf install parallel"
      elif command -v pacman >/dev/null 2>&1; then
        log "  sudo pacman -S parallel"
      else
        log "  Visit: https://www.gnu.org/software/parallel/"
      fi ;;
  esac
  log_info "Continuing with sequential builds..."
}

# Generate persistent builder name per container
get_builder_name() {
  local container_name="$1"
  echo "dotfiles_builder_${container_name}"
}

# Create BuildKit builder
create_builder() {
  local builder_name="$1"
  local container_name="$2"
  local buildkitd_args=()

  if docker buildx inspect "$builder_name" >/dev/null 2>&1; then
    docker buildx use "$builder_name" >/dev/null 2>&1 || true
    log_info "[${container_name}] Reusing existing builder ${builder_name}"
    return 0
  fi

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

# Usage
usage() {
  cat << EOF
Usage: \$0 [OPTIONS] [CONTAINER_NAMES...]

Build and test Docker containers.

OPTIONS:
  -h, --help                    Show this help message
  -l, --list                    List available containers and exit
  -c, --config CONFIG_PATH      Use custom buildkitd config file
                                (default: ~/.config/docker/buildkitd/buildkitd.toml)
      --full-test               Build test stage (full install) instead of release image
  --ca-certs PATH           Provide a PEM bundle to inject into system trust store (mounted as secret)

EXAMPLES:
  \$0                                    # Build all containers
  \$0 archlinux                          # Build only archlinux container
  \$0 fedora                             # Build only fedora container
  \$0 --list                             # List available containers
  \$0 --config /path/to/buildkitd.toml   # Use custom buildkitd config

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
BUILD_TEST=false
CA_CERTS_PATH=""

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
    --ca-certs)
      if [ -z "${2:-}" ]; then
        log_error "Option $1 requires an argument"
        usage
        exit 1
      fi
      CA_CERTS_PATH="$2"
      shift 2
      ;;
    --full-test) BUILD_TEST=true; shift ;;
    -*) log_error "Unknown option: $1"; usage; exit 1 ;;
    *) SELECTED_CONTAINERS+=("$1"); shift ;;
  esac
done

# Build and run container
run_container() {
  local dir="$1"
  local name
  local default_tag
  local test_tag
  local builder_name
  local target_stage=""
  local build_stage_label="release image"

  name="$(basename "$dir")"
  default_tag="dotfiles-${name}"
  test_tag="${default_tag}-test"
  builder_name="$(get_builder_name "$name")"

  log "🐳 [${name}] build start"

  if ! create_builder "$builder_name" "$name"; then
    log_error "[${name}] failed to create builder"
    exit 1
  fi

  local tag="${default_tag}"

  if [ "$BUILD_TEST" = true ]; then
    target_stage="test"
    tag="${test_tag}"
    build_stage_label="test stage"
  fi

  log_info "[${name}] building ${build_stage_label} (${tag})"

  local cache_bust
  cache_bust="$(date +%s)"

  local build_args=(
    --builder "$builder_name"
    --progress=plain
    --load
    -t "$tag"
    -f "${dir}/Dockerfile"
    --build-arg "CACHE_BUST=${cache_bust}"
  )

  if [ -n "$target_stage" ]; then
    build_args+=(--target "$target_stage")
  fi

  # Secrets array
  local secret_args=()
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    secret_args+=("--secret" "id=GITHUB_TOKEN,src=/dev/stdin")
  fi
  if [ -n "$CA_CERTS_PATH" ]; then
    if [ ! -f "$CA_CERTS_PATH" ]; then
      log_error "CA certs file not found: $CA_CERTS_PATH"
      exit 1
    fi
    secret_args+=("--secret" "id=CUSTOM_CA,src=$(realpath "$CA_CERTS_PATH")")
    log_info "[${name}] injecting custom CA bundle"
  fi

  if [ -n "${GITHUB_TOKEN:-}" ]; then
    printf '%s' "${GITHUB_TOKEN}" | docker buildx build "${build_args[@]}" "${secret_args[@]}" "${ROOT_DIR}"
  else
    docker buildx build "${build_args[@]}" "${secret_args[@]}" "${ROOT_DIR}"
  fi || {
    log_error "[${name}] build failed for ${build_stage_label}"
    exit 1
  }

  local working_dir
  working_dir="$(docker image inspect "${tag}" --format '{{ .Config.WorkingDir }}' 2>/dev/null || true)"
  if [ -z "$working_dir" ]; then
    working_dir="/home/devcontainer"
  fi

  log "🚀 [${name}] run start (${build_stage_label})"
  docker run --rm -w "${working_dir}" "${tag}" || { log_error "[${name}] ${build_stage_label} failed"; exit 1; }

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

  export -f run_container run_container_parallel get_name get_builder_name create_builder log log_info log_success log_error
  export ROOT_DIR BUILDKITD_CONFIG BUILD_TEST

  run_containers "${containers[@]}"
  log_success "All containers tested successfully!"
}

main
