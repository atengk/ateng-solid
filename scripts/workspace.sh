#!/usr/bin/env bash
# ==============================================================================
# ateng-solid 多仓库聚合工作区全生命周期治理脚本
#
# 支持子命令:
#   status                         巡检根仓与各子仓分支、工作区洁净度、Hooks 与公共规约同步状态
#   init                           幂等初始化: 配置 Git Hooks、准备 dev 开发分支、检查本地工具链基线
#   sync [--pull]                  克隆缺失子仓；传入 --pull 时在干净工作区增量拉取，并同步公共规约
#   sync-rules                     将根仓 .agents/rules/ 公共真源单向同步至各子仓（兼容 sync-contracts）
#   check-rules [--allow-missing]  校验根仓与各子仓公共规约一致性（兼容 check-contracts）
#   sync-contracts                 [兼容别名] 等同于 sync-rules
#   check-contracts [--allow-missing]  [兼容别名] 等同于 check-rules
#   checkout <branch>              全工作区洁净检查后统一切换分支（如 dev / main）
#
# @author Ateng
# @since 2026-11-18
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

SHARED_RULES=(
  ".agents/rules/contracts.md"
  ".agents/rules/foundation-first-gate.md"
  ".agents/rules/coding-and-architecture.md"
  "docs/agents/documentation-specification.md"
)

REPOS=(
  "ateng-solid-server|https://github.com/atengk/ateng-solid-server.git"
  "ateng-solid-admin-web|https://github.com/atengk/ateng-solid-admin-web.git"
)

if [ -t 1 ]; then
  C_RESET="\033[0m"
  C_BOLD="\033[1m"
  C_GREEN="\033[32m"
  C_YELLOW="\033[33m"
  C_RED="\033[31m"
  C_CYAN="\033[36m"
else
  C_RESET=""
  C_BOLD=""
  C_GREEN=""
  C_YELLOW=""
  C_RED=""
  C_CYAN=""
fi

log_info() { printf "%b[INFO]%b %s\n" "${C_CYAN}" "${C_RESET}" "$1"; }
log_ok() { printf "%b[OK]%b %s\n" "${C_GREEN}" "${C_RESET}" "$1"; }
log_warn() { printf "%b[WARN]%b %s\n" "${C_YELLOW}" "${C_RESET}" "$1" >&2; }
log_err() { printf "%b[ERROR]%b %s\n" "${C_RED}" "${C_RESET}" "$1" >&2; }

show_help() {
  cat <<'EOF'
用法: bash scripts/workspace.sh <子命令> [选项]

子命令:
  status                            查看工作区全仓状态（分支、变更、Hooks、公共规约一致性）
  init                              幂等初始化全仓 Git Hooks、dev 开发分支并巡检本地工具链
  sync [--pull]                     克隆缺失子仓；带 --pull 时对干净子仓拉取更新并同步公共规约
  sync-rules                        将根仓公共规约 (contracts / foundation-first-gate / coding-and-architecture / documentation-specification) 单向同步至各子仓
  check-rules [--allow-missing]     校验全仓公共规约一致性（CI 可传 --allow-missing）
  sync-contracts                    [兼容别名] 等同于 sync-rules
  check-contracts [--allow-missing] [兼容别名] 等同于 check-rules
  checkout <branch>                 全部仓库干净时统一切换至目标分支（如 dev 或 main）
  help                              显示帮助说明
EOF
}

configure_hooks() {
  local repo_path="$1"
  local label="$2"
  if [[ ! -d "$repo_path/.git" ]]; then
    return 0
  fi
  if [[ -d "$repo_path/.githooks" ]]; then
    chmod +x "$repo_path/.githooks/"* 2>/dev/null || true
    local current_hooks
    current_hooks="$(git -C "$repo_path" config --get core.hooksPath 2>/dev/null || true)"
    if [[ "$current_hooks" != ".githooks" ]]; then
      git -C "$repo_path" config core.hooksPath .githooks
      log_ok "[$label] 已激活 core.hooksPath = .githooks"
    else
      log_info "[$label] core.hooksPath 已激活 (.githooks)"
    fi
  fi
  if [[ -d "$repo_path/scripts" ]]; then
    chmod +x "$repo_path/scripts/"*.sh 2>/dev/null || true
  fi
}

ensure_dev_branch() {
  local repo_path="$1"
  local label="$2"
  if [[ ! -d "$repo_path/.git" ]]; then
    return 0
  fi
  local current_branch
  current_branch="$(git -C "$repo_path" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
  if [[ "$current_branch" == "dev" ]]; then
    log_info "[$label] 当前已在 dev 分支"
    return 0
  fi
  if [[ -n "$(git -C "$repo_path" status --porcelain)" ]]; then
    log_warn "[$label] 工作区存在未提交改动，跳过自动切换 dev 分支（当前: $current_branch）"
    return 0
  fi
  if git -C "$repo_path" show-ref --verify --quiet refs/heads/dev; then
    git -C "$repo_path" checkout dev
    log_ok "[$label] 已切换至本地 dev 分支"
  elif git -C "$repo_path" show-ref --verify --quiet refs/remotes/origin/dev; then
    git -C "$repo_path" checkout -b dev origin/dev
    log_ok "[$label] 已基于 origin/dev 检出 dev 分支"
  else
    git -C "$repo_path" checkout -b dev
    log_ok "[$label] 已基于当前提交新建 dev 分支"
  fi
}

check_toolchain() {
  log_info "正在巡检本地工具链基线（Java 21 / Maven 3.9+ / Node 22+ / pnpm 11+）..."
  if command -v java >/dev/null 2>&1; then
    local jver
    jver="$(java -version 2>&1 | head -n 1 | tr -d '\r')"
    log_ok "Java: $jver"
  else
    log_warn "未检测到 java 命令（后端基线要求 OpenJDK 21 LTS）"
  fi

  if command -v mvn >/dev/null 2>&1; then
    local mver
    mver="$(mvn -v 2>&1 | head -n 1 | tr -d '\r')"
    log_ok "Maven: $mver"
  else
    log_warn "未检测到 mvn 命令（后端基线要求 Maven 3.9+）"
  fi

  if command -v node >/dev/null 2>&1; then
    log_ok "Node.js: $(node -v | tr -d '\r')"
  else
    log_warn "未检测到 node 命令（前端基线要求 Node.js >= 22）"
  fi

  if command -v pnpm >/dev/null 2>&1; then
    log_ok "pnpm: v$(pnpm -v | tr -d '\r')"
  else
    log_warn "未检测到 pnpm 命令（前端基线要求 pnpm 11+）"
  fi
}

sync_rules() {
  for rule_rel in "${SHARED_RULES[@]}"; do
    local src="$ROOT_DIR/$rule_rel"
    if [[ ! -f "$src" ]]; then
      log_err "未找到公共规约真源: $src"
      exit 1
    fi
  done

  for item in "${REPOS[@]}"; do
    local name="${item%%|*}"
    local repo_dir="$ROOT_DIR/$name"
    if [[ ! -d "$repo_dir/.git" ]]; then
      log_warn "[$name] 尚未克隆，跳过公共规约同步"
      continue
    fi
    for rule_rel in "${SHARED_RULES[@]}"; do
      local src="$ROOT_DIR/$rule_rel"
      local dst="$repo_dir/$rule_rel"
      mkdir -p "$(dirname "$dst")"
      if [[ -f "$dst" ]] && cmp -s "$src" "$dst"; then
        log_info "[$name] $rule_rel 已是最新"
      else
        cp "$src" "$dst"
        log_ok "[$name] 已同步最新 $rule_rel"
      fi
    done
  done
}

check_rules() {
  local allow_missing="${1:-false}"
  for rule_rel in "${SHARED_RULES[@]}"; do
    local src="$ROOT_DIR/$rule_rel"
    if [[ ! -f "$src" ]]; then
      log_err "未找到公共规约真源: $src"
      exit 1
    fi
  done

  local failed=false
  for item in "${REPOS[@]}"; do
    local name="${item%%|*}"
    local repo_dir="$ROOT_DIR/$name"
    if [[ ! -d "$repo_dir/.git" ]]; then
      if [[ "$allow_missing" == "true" ]]; then
        log_info "[$name] 未检出子仓，已按 --allow-missing 跳过"
        continue
      fi
      log_err "[$name] 子仓缺失，无法校验公共规约"
      failed=true
      continue
    fi
    for rule_rel in "${SHARED_RULES[@]}"; do
      local src="$ROOT_DIR/$rule_rel"
      local dst="$repo_dir/$rule_rel"
      if [[ ! -f "$dst" ]]; then
        log_err "[$name] 缺少规约副本: $dst（请运行 bash scripts/workspace.sh sync-rules）"
        failed=true
        continue
      fi
      if cmp -s "$src" "$dst"; then
        log_ok "[$name] $rule_rel 一致"
      else
        log_err "[$name] $rule_rel 已漂移！请运行 bash scripts/workspace.sh sync-rules 同步"
        failed=true
      fi
    done
  done

  if [[ "$failed" == "true" ]]; then
    exit 1
  fi
}

show_repo_status() {
  local label="$1"
  local path="$2"
  if [[ ! -d "$path/.git" ]]; then
    printf "%b[MISSING]%b %s (%s)\n" "${C_YELLOW}" "${C_RESET}" "$label" "$path"
    return 0
  fi

  local branch
  branch="$(git -C "$path" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
  local hooks_path
  hooks_path="$(git -C "$path" config --get core.hooksPath 2>/dev/null || echo "unset")"
  local dirty
  dirty="$(git -C "$path" status --short)"

  local rules_tag=""
  if [[ "$label" != "ateng-solid (root)" ]]; then
    local all_ok=true
    for rule_rel in "${SHARED_RULES[@]}"; do
      local src="$ROOT_DIR/$rule_rel"
      local dst="$path/$rule_rel"
      if [[ ! -f "$dst" ]] || ! cmp -s "$src" "$dst"; then
        all_ok=false
        break
      fi
    done
    if [[ "$all_ok" == "true" ]]; then
      rules_tag="rules:ok"
    else
      rules_tag="rules:DRIFT"
    fi
  fi

  if [[ -n "$dirty" ]]; then
    printf "%b[DIRTY]%b   %-24s [branch:%s | hooks:%s%s]\n" \
      "${C_CYAN}" "${C_RESET}" "$label" "$branch" "$hooks_path" "${rules_tag:+ | $rules_tag}"
    printf '%s\n' "$dirty" | sed 's/^/          /'
  else
    printf "%b[CLEAN]%b   %-24s [branch:%s | hooks:%s%s]\n" \
      "${C_GREEN}" "${C_RESET}" "$label" "$branch" "$hooks_path" "${rules_tag:+ | $rules_tag}"
  fi
}

cmd_status() {
  printf "\n%b=== ateng-solid Workspace Status ===%b\n" "${C_BOLD}" "${C_RESET}"
  show_repo_status "ateng-solid (root)" "$ROOT_DIR"
  for item in "${REPOS[@]}"; do
    local name="${item%%|*}"
    show_repo_status "$name" "$ROOT_DIR/$name"
  done
}

cmd_init() {
  configure_hooks "$ROOT_DIR" "ateng-solid"
  ensure_dev_branch "$ROOT_DIR" "ateng-solid"
  for item in "${REPOS[@]}"; do
    local name="${item%%|*}"
    local target="$ROOT_DIR/$name"
    if [[ ! -d "$target/.git" ]]; then
      log_warn "[$name] 未克隆，可先运行 bash scripts/workspace.sh sync"
      continue
    fi
    configure_hooks "$target" "$name"
    ensure_dev_branch "$target" "$name"
  done
  sync_rules
  check_toolchain
  cmd_status
}

cmd_sync() {
  local do_pull=false
  if [[ "${1:-}" == "--pull" ]]; then
    do_pull=true
  elif [[ -n "${1:-}" ]]; then
    log_err "未知 sync 参数: $1"
    exit 1
  fi

  for item in "${REPOS[@]}"; do
    local name="${item%%|*}"
    local url="${item##*|}"
    local target="$ROOT_DIR/$name"
    if [[ ! -d "$target/.git" ]]; then
      log_info "正在克隆 $name ($url)..."
      git clone "$url" "$target"
      configure_hooks "$target" "$name"
      continue
    fi
    if [[ "$do_pull" == "true" ]]; then
      if [[ -n "$(git -C "$target" status --short)" ]]; then
        log_warn "[$name] 存在未提交改动，已跳过自动拉取"
      else
        log_info "[$name] 正在拉取更新 (--ff-only)..."
        git -C "$target" pull --ff-only
      fi
    fi
  done
  sync_rules
  cmd_status
}

cmd_checkout() {
  local target_branch="${1:-}"
  if [[ -z "$target_branch" ]]; then
    log_err "请指定目标分支名，例如: bash scripts/workspace.sh checkout dev"
    exit 1
  fi

  local check_paths=("$ROOT_DIR")
  for item in "${REPOS[@]}"; do
    local name="${item%%|*}"
    if [[ -d "$ROOT_DIR/$name/.git" ]]; then
      check_paths+=("$ROOT_DIR/$name")
    fi
  done

  for repo_path in "${check_paths[@]}"; do
    if [[ -n "$(git -C "$repo_path" status --porcelain)" ]]; then
      log_err "工作区不干净，安全中止全仓切换分支: $repo_path"
      exit 1
    fi
  done

  for repo_path in "${check_paths[@]}"; do
    local label
    label="$(basename "$repo_path")"
    if git -C "$repo_path" show-ref --verify --quiet "refs/heads/$target_branch"; then
      git -C "$repo_path" checkout "$target_branch"
      log_ok "[$label] 已切换至 $target_branch"
    elif git -C "$repo_path" show-ref --verify --quiet "refs/remotes/origin/$target_branch"; then
      git -C "$repo_path" checkout -b "$target_branch" "origin/$target_branch"
      log_ok "[$label] 已检出远程分支 origin/$target_branch"
    else
      log_err "[$label] 不存在分支 $target_branch"
      exit 1
    fi
  done
}

ACTION="${1:-status}"
shift || true

case "$ACTION" in
  status)
    cmd_status
    ;;
  init)
    cmd_init
    ;;
  sync)
    cmd_sync "${1:-}"
    ;;
  sync-rules|sync-contracts)
    sync_rules
    ;;
  check-rules|check-contracts)
    if [[ "${1:-}" == "--allow-missing" ]]; then
      check_rules true
    elif [[ -n "${1:-}" ]]; then
      log_err "未知 $ACTION 参数: $1"
      exit 1
    else
      check_rules false
    fi
    ;;
  checkout)
    cmd_checkout "${1:-}"
    ;;
  help|-h|--help)
    show_help
    ;;
  *)
    log_err "未知子命令: $ACTION"
    show_help
    exit 1
    ;;
esac
