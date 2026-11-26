#!/usr/bin/env bash
# ==============================================================================
# ateng-solid 全栈聚合工作区运行时管理脚本
#
# 统一编排本地开发联调与产物构建生命周期：
#   - server    复用 ateng-solid-server/scripts/server.sh（Java 21 + Fat JAR）
#   - admin-web 统筹管理 ateng-solid-admin-web（Vite dev / preview / build）
#
# 支持子命令：
#   start   [all|server|admin-web] [选项] [-- <单端运行参数...>]
#   stop    [all|server|admin-web] [--force]
#   restart [all|server|admin-web] [选项] [-- <单端运行参数...>]
#   status  [all|server|admin-web]
#   logs    [all|server|admin-web] [-f|--follow] [-n|--lines 100] [--error]
#   build   [all|server|admin-web] [--clean] [--with-tests]
#   check   [all|server|admin-web] [选项]
#   help    显示帮助说明（无子命令时默认执行）
#
# @author Ateng
# @since 2026-11-26
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

SERVER_DIR="$ROOT_DIR/ateng-solid-server"
SERVER_SCRIPT="$SERVER_DIR/scripts/server.sh"
ADMIN_WEB_DIR="$ROOT_DIR/ateng-solid-admin-web"

LOG_DIR="${SOLID_LOG_DIR:-$ROOT_DIR/logs}"
PID_DIR="${SOLID_PID_DIR:-$ROOT_DIR/tmp/run}"

ACTION=""
TARGET=""

OPT_PROFILE="${SPRING_PROFILES_ACTIVE:-dev}"
OPT_SERVER_PORT=""
OPT_WEB_PORT=""
OPT_SINGLE_PORT=""
OPT_ENV_FILE=""
OPT_JAR="${APP_JAR:-}"
OPT_JVM_OPTS="${JAVA_OPTS:-}"
OPT_JVM_OPTS_SET=false
OPT_SERVER_ARGS="${SOLID_APP_ARGS:-}"
OPT_SERVER_ARGS_SET=false
OPT_WEB_ARGS="${SOLID_WEB_ARGS:-}"
OPT_WEB_ARGS_SET=false
TRAILING_ARGS=()
RESOLVED_WEB_ARGS_ARR=()
OPT_BUILD=false
OPT_CLEAN=false
OPT_WITH_TESTS=false
OPT_PREVIEW=false
OPT_FG=false
OPT_FORCE=false
OPT_SKIP_ENV_CHECK=false
OPT_START_TIMEOUT=""
OPT_STOP_TIMEOUT=25
OPT_FOLLOW=false
OPT_LINES=100
OPT_ERROR_LOG=false

if [[ -t 1 ]]; then
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
用法: bash scripts/solid.sh [子命令] [目标: all|server|admin-web] [选项] [-- <单端运行参数...>]

无子命令时默认显示本帮助说明（查询状态请显式执行 status）。

子命令:
  start   [目标]    启动全栈或指定服务（默认 all：先启 server 再启 admin-web）
  stop    [目标]    优雅停止服务（默认 all：先停 admin-web 再停 server）
  restart [目标]    重启服务（先停后启，可组合 --build）
  status  [目标]    查看全栈各端运行状态、PID、端口与日志文件
  logs    [目标]    查看日志（不传目标默认聚合查看全部运行日志）
  build   [目标]    构建产物（server 打包 Fat JAR；admin-web 执行 pnpm build）
  check   [目标]    轻量巡检（工具链、本地配置文件、依赖安装与端口状态）
  help              显示本帮助信息

目标别名:
  all               全部已落地端（默认）
  server            ateng-solid-server 后端服务
  admin-web         ateng-solid-admin-web 前端管理后台（兼容别名: web, admin）

常用选项（所有带值选项均同时支持 --opt val 与 --opt=val 写法）:
  -p, --profile <dev|prod>    后端激活 Profile（默认: dev）
      --server-port <port>    指定后端端口（默认: 8080）
      --web-port <port>       指定前端端口（默认读取 .env.local/.env.development 中 VITE_PORT 或 5173）
      --port <port>           单服务模式下直接指定端口（目标为 all 时请用 --server-port / --web-port）
      --env-file <path>       透传环境变量文件至后端脚本
      --jar <path>            透传可运行 Fat JAR 路径至后端脚本
      --jvm-opts "<opts>"     透传自定义 JVM 参数至后端脚本（覆盖 JAVA_OPTS）
      --server-args "<args>"  自定义后端 Spring Boot 应用参数（覆盖 SOLID_APP_ARGS，仅 start/restart）
      --web-args "<args>"     自定义前端 Vite 启动参数（覆盖 SOLID_WEB_ARGS，仅 start/restart）
      --build                 启动或重启前先构建产物
      --clean                 后端构建时执行 clean package
      --with-tests            构建时执行测试/门禁（后端 mvn test；前端 typecheck+lint+test+build）
      --preview               前端改用 pnpm preview 验证生产 dist 构建产物
      --fg                    单服务前台调试模式（不可与 all 混用）
      --force                 stop/restart 时强制清理未纳管的端口占用进程
      --skip-env-check        透传至后端跳过 prod 必填 SOLID_* 变量校验
      --timeout <sec>         启动就绪等待超时秒数
      --stop-timeout <sec>    停止等待超时秒数（默认: 25）
  -f, --follow                logs 子命令持续追踪日志输出
  -n, --lines <num>           logs 子命令显示行数（默认: 100）
      --error                 查看后端 prod 错误日志 (*-error.log)

运行时参数透传（仅 start / restart 支持）:
  -- <args...>                单端目标（server 或 admin-web）时按原样透传给对应进程，追加在命名参数之后；
                              目标为 all 时请用 --server-args / --web-args 分别传入。
                              注：端口与 Profile 冲突键（--server.port* / --spring.profiles.active* / Vite --port）
                              请统一使用 --server-port / --web-port / --port / -p。
EOF
}

is_windows() {
  case "$(uname -s 2>/dev/null || echo unknown)" in
    MINGW*|MSYS*|CYGWIN*) return 0 ;;
    *) return 1 ;;
  esac
}

is_positive_int() {
  [[ "${1:-}" =~ ^[0-9]+$ ]] && [[ "$1" -gt 0 ]]
}

trim_spaces() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

SPLIT_ARGS_RESULT=()

split_cli_args() {
  local raw="${1:-}"
  SPLIT_ARGS_RESULT=()
  local len=${#raw}
  local i=0
  local current=""
  local has_token=false
  local quote=""
  local ch=""
  local next_ch=""

  while [[ "$i" -lt "$len" ]]; do
    ch="${raw:i:1}"
    if [[ -n "$quote" ]]; then
      if [[ "$quote" == "'" ]]; then
        if [[ "$ch" == "'" ]]; then
          quote=""
        else
          current+="$ch"
        fi
      else
        if [[ "$ch" == '"' ]]; then
          quote=""
        elif [[ "$ch" == '\' ]]; then
          if [[ $((i + 1)) -ge "$len" ]]; then
            log_err "参数字符串末尾存在悬空转义符: $raw"
            exit 1
          fi
          next_ch="${raw:$((i + 1)):1}"
          case "$next_ch" in
            '"'|'\'|'$'|'`') current+="$next_ch" ;;
            *) current+="\\$next_ch" ;;
          esac
          i=$((i + 1))
        else
          current+="$ch"
        fi
      fi
    else
      case "$ch" in
        ' '|$'\t'|$'\n'|$'\r')
          if [[ "$has_token" == "true" ]]; then
            SPLIT_ARGS_RESULT+=("$current")
            current=""
            has_token=false
          fi
          ;;
        "'"|'"')
          quote="$ch"
          has_token=true
          ;;
        '\')
          if [[ $((i + 1)) -ge "$len" ]]; then
            log_err "参数字符串末尾存在悬空转义符: $raw"
            exit 1
          fi
          i=$((i + 1))
          current+="${raw:i:1}"
          has_token=true
          ;;
        *)
          current+="$ch"
          has_token=true
          ;;
      esac
    fi
    i=$((i + 1))
  done

  if [[ -n "$quote" ]]; then
    log_err "参数字符串引号未闭合: $raw"
    exit 1
  fi
  if [[ "$has_token" == "true" ]]; then
    SPLIT_ARGS_RESULT+=("$current")
  fi
}

validate_runtime_args() {
  if [[ "$OPT_SERVER_ARGS_SET" == "true" || "$OPT_WEB_ARGS_SET" == "true" || "${#TRAILING_ARGS[@]}" -gt 0 ]]; then
    if [[ "$ACTION" != "start" && "$ACTION" != "restart" ]]; then
      log_err "仅 start / restart 支持通过 --server-args / --web-args 或 -- 传入运行参数（当前子命令: $ACTION）"
      exit 1
    fi
  fi

  if [[ "${#TRAILING_ARGS[@]}" -gt 0 && "$TARGET" == "all" ]]; then
    log_err "目标为 all 时不支持末尾 -- 透传（前后端参数不互通）；请显式指定单端目标（server / admin-web），或改用 --server-args / --web-args 分别传入"
    exit 1
  fi

  if [[ "$ACTION" != "start" && "$ACTION" != "restart" ]]; then
    return 0
  fi

  local item

  # 1. 预先校验后端 JVM / 应用参数语法与冲突，避免 restart 先停后挂
  if [[ "$TARGET" == "all" || "$TARGET" == "server" ]]; then
    if [[ -n "$OPT_JVM_OPTS" ]]; then
      split_cli_args "$OPT_JVM_OPTS"
      if [[ "${#SPLIT_ARGS_RESULT[@]}" -gt 0 ]]; then
        for item in "${SPLIT_ARGS_RESULT[@]}"; do
          case "$item" in
            -Dserver.port|-Dserver.port=*|-Dspring.profiles.active|-Dspring.profiles.active=*)
              log_err "检测到与脚本主参数冲突的 JVM 属性 ($item)，请统一使用 --server-port / --port 或 -p/--profile"
              exit 1
              ;;
          esac
        done
      fi
    fi

    local srv_check_arr=()
    if [[ -n "$OPT_SERVER_ARGS" ]]; then
      split_cli_args "$OPT_SERVER_ARGS"
      if [[ "${#SPLIT_ARGS_RESULT[@]}" -gt 0 ]]; then
        srv_check_arr=("${SPLIT_ARGS_RESULT[@]}")
      fi
    fi
    if [[ "$TARGET" == "server" && "${#TRAILING_ARGS[@]}" -gt 0 ]]; then
      srv_check_arr+=("${TRAILING_ARGS[@]}")
    fi
    if [[ "${#srv_check_arr[@]}" -gt 0 ]]; then
      for item in "${srv_check_arr[@]}"; do
        case "$item" in
          --server.port|--server.port=*|--spring.profiles.active|--spring.profiles.active=*)
            log_err "检测到与脚本主参数冲突的后端参数 ($item)，请统一使用 --server-port / --port 或 -p/--profile"
            exit 1
            ;;
        esac
      done
    fi
  fi

  # 2. 解析并校验前端 Vite 参数
  RESOLVED_WEB_ARGS_ARR=()
  if [[ "$TARGET" == "all" || "$TARGET" == "admin-web" ]]; then
    if [[ -n "$OPT_WEB_ARGS" ]]; then
      split_cli_args "$OPT_WEB_ARGS"
      if [[ "${#SPLIT_ARGS_RESULT[@]}" -gt 0 ]]; then
        RESOLVED_WEB_ARGS_ARR=("${SPLIT_ARGS_RESULT[@]}")
      fi
    fi
    if [[ "$TARGET" == "admin-web" && "${#TRAILING_ARGS[@]}" -gt 0 ]]; then
      RESOLVED_WEB_ARGS_ARR+=("${TRAILING_ARGS[@]}")
    fi
    if [[ "${#RESOLVED_WEB_ARGS_ARR[@]}" -gt 0 ]]; then
      for item in "${RESOLVED_WEB_ARGS_ARR[@]}"; do
        case "$item" in
          --port|--port=*)
            log_err "检测到与脚本主参数冲突的前端端口参数 ($item)，请统一使用 --web-port 或 --port（单端模式）"
            exit 1
            ;;
        esac
      done
    fi
  fi
}

read_env_key_from_file() {
  local file="$1"
  local target_key="$2"
  [[ -f "$file" ]] || return 0
  local line key val first_char last_char
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    line="$(trim_spaces "$line")"
    [[ -z "$line" || "$line" == \#* ]] && continue
    if [[ "$line" == export\ * ]]; then
      line="$(trim_spaces "${line#export }")"
    fi
    [[ "$line" != *=* ]] && continue
    key="$(trim_spaces "${line%%=*}")"
    [[ "$key" == "$target_key" ]] || continue
    val="$(trim_spaces "${line#*=}")"
    if [[ "${#val}" -ge 2 ]]; then
      first_char="${val:0:1}"
      last_char="${val: -1}"
      if [[ ( "$first_char" == '"' && "$last_char" == '"' ) || ( "$first_char" == "'" && "$last_char" == "'" ) ]]; then
        val="${val:1:${#val}-2}"
      fi
    fi
    printf '%s' "$val"
    return 0
  done < "$file"
}

meta_get() {
  local file="$1"
  local target_key="$2"
  [[ -f "$file" ]] || return 0
  local line key val
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    [[ -z "$line" || "$line" == \#* ]] && continue
    key="${line%%=*}"
    val="${line#*=}"
    if [[ "$key" == "$target_key" ]]; then
      printf '%s' "$val"
      return 0
    fi
  done < "$file"
}

get_port_pids() {
  local port="$1"
  if is_windows; then
    netstat -ano -p tcp 2>/dev/null | tr -d '\r' | awk -v p=":${port}" '
      $1 == "TCP" && $4 == "LISTENING" {
        plen = length(p)
        alen = length($2)
        if (alen > plen && substr($2, alen - plen + 1) == p && $5 ~ /^[0-9]+$/) {
          print $5
        }
      }
    ' | sort -u
    return 0
  fi

  if command -v lsof >/dev/null 2>&1; then
    lsof -nP -iTCP:"$port" -sTCP:LISTEN -t 2>/dev/null | sort -u || true
  elif command -v ss >/dev/null 2>&1; then
    ss -tlnp 2>/dev/null | awk -v p=":${port}" '
      $1 == "LISTEN" {
        plen = length(p)
        alen = length($4)
        if (alen > plen && substr($4, alen - plen + 1) == p) {
          line = $0
          while (match(line, /pid=[0-9]+/)) {
            pid = substr(line, RSTART + 4, RLENGTH - 4)
            print pid
            line = substr(line, RSTART + RLENGTH)
          }
        }
      }
    ' | sort -u
  elif command -v netstat >/dev/null 2>&1; then
    netstat -tlnp 2>/dev/null | awk -v p=":${port}" '
      $6 == "LISTEN" {
        plen = length(p)
        alen = length($4)
        if (alen > plen && substr($4, alen - plen + 1) == p) {
          split($7, arr, "/")
          if (arr[1] ~ /^[0-9]+$/) print arr[1]
        }
      }
    ' | sort -u
  fi
}

is_port_listening() {
  local port="$1"
  local pids
  pids="$(get_port_pids "$port" || true)"
  if [[ -n "$pids" ]]; then
    return 0
  fi
  if ! is_windows && ! command -v lsof >/dev/null 2>&1 && ! command -v ss >/dev/null 2>&1 && ! command -v netstat >/dev/null 2>&1; then
    if (echo >/dev/tcp/127.0.0.1/"$port") >/dev/null 2>&1; then
      return 0
    fi
  fi
  return 1
}

get_winpid_for_msys_pid() {
  local msys_pid="$1"
  local tries=0
  local winpid=""
  while [[ "$tries" -lt 3 ]]; do
    winpid="$(ps -W -p "$msys_pid" 2>/dev/null | awk 'NR==2 {print $4}' || true)"
    if [[ "$winpid" =~ ^[0-9]+$ ]]; then
      printf '%s' "$winpid"
      return 0
    fi
    tries=$((tries + 1))
    sleep 1
  done
}

is_pid_alive() {
  local msys_pid="${1:-}"
  local winpid="${2:-}"
  if [[ -n "$msys_pid" ]] && kill -0 "$msys_pid" 2>/dev/null; then
    return 0
  fi
  if is_windows && [[ -n "$winpid" ]]; then
    if ps -W 2>/dev/null | awk -v wp="$winpid" '$4 == wp { found=1 } END { exit !found }'; then
      return 0
    fi
  fi
  return 1
}

kill_windows_pid_tree() {
  local winpid="$1"
  local force="${2:-false}"
  [[ -n "$winpid" ]] || return 0
  if [[ "$force" == "true" ]]; then
    taskkill //PID "$winpid" //T //F >/dev/null 2>&1 || true
  else
    taskkill //PID "$winpid" //T >/dev/null 2>&1
  fi
}

stop_process_tree() {
  local msys_pid="${1:-}"
  local winpid="${2:-}"
  local port_pid="${3:-}"
  local timeout="$4"

  if is_windows; then
    local target_wp="${winpid:-$port_pid}"
    local wm_close_ok=false
    if [[ -n "$target_wp" ]] && kill_windows_pid_tree "$target_wp" false; then
      wm_close_ok=true
    elif [[ -n "$msys_pid" ]]; then
      kill -TERM "$msys_pid" 2>/dev/null || true
    fi

    local wait_limit="$timeout"
    if [[ "$wm_close_ok" == "false" ]] && [[ "$wait_limit" -gt 3 ]]; then
      wait_limit=3
    fi

    local elapsed=0
    while [[ "$elapsed" -lt "$wait_limit" ]]; do
      if ! is_pid_alive "$msys_pid" "$winpid" && { [[ -z "$port_pid" ]] || ! is_pid_alive "" "$port_pid"; }; then
        return 0
      fi
      sleep 1
      elapsed=$((elapsed + 1))
    done

    [[ -n "$winpid" ]] && kill_windows_pid_tree "$winpid" true
    [[ -n "$port_pid" && "$port_pid" != "$winpid" ]] && kill_windows_pid_tree "$port_pid" true
    [[ -n "$msys_pid" ]] && kill -KILL "$msys_pid" 2>/dev/null || true
    sleep 1
    return 0
  fi

  [[ -n "$msys_pid" ]] && kill -TERM "$msys_pid" 2>/dev/null || true
  [[ -n "$port_pid" && "$port_pid" != "$msys_pid" ]] && kill -TERM "$port_pid" 2>/dev/null || true

  local elapsed=0
  while [[ "$elapsed" -lt "$timeout" ]]; do
    if ! is_pid_alive "$msys_pid" "" && { [[ -z "$port_pid" ]] || ! is_pid_alive "$port_pid" ""; }; then
      return 0
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done

  [[ -n "$msys_pid" ]] && kill -KILL "$msys_pid" 2>/dev/null || true
  [[ -n "$port_pid" && "$port_pid" != "$msys_pid" ]] && kill -KILL "$port_pid" 2>/dev/null || true
  sleep 1
}

resolve_server_port() {
  if [[ -n "$OPT_SERVER_PORT" ]]; then
    printf '%s' "$OPT_SERVER_PORT"
  elif [[ "$TARGET" == "server" && -n "$OPT_SINGLE_PORT" ]]; then
    printf '%s' "$OPT_SINGLE_PORT"
  else
    printf '%s' "${SERVER_PORT:-8080}"
  fi
}

resolve_web_port() {
  if [[ -n "$OPT_WEB_PORT" ]]; then
    printf '%s' "$OPT_WEB_PORT"
    return 0
  fi
  if [[ "$TARGET" == "admin-web" && -n "$OPT_SINGLE_PORT" ]]; then
    printf '%s' "$OPT_SINGLE_PORT"
    return 0
  fi
  local p=""
  p="$(read_env_key_from_file "$ADMIN_WEB_DIR/.env.local" "VITE_PORT")"
  if [[ -z "$p" ]]; then
    p="$(read_env_key_from_file "$ADMIN_WEB_DIR/.env.development" "VITE_PORT")"
  fi
  printf '%s' "${p:-5173}"
}

resolve_web_proxy_target() {
  local target=""
  target="$(read_env_key_from_file "$ADMIN_WEB_DIR/.env.local" "VITE_PROXY_TARGET")"
  if [[ -z "$target" ]]; then
    target="$(read_env_key_from_file "$ADMIN_WEB_DIR/.env.development" "VITE_PROXY_TARGET")"
  fi
  printf '%s' "${target:-http://127.0.0.1:8080}"
}

ensure_server_repo() {
  if [[ ! -f "$SERVER_SCRIPT" ]]; then
    log_err "未找到后端管理脚本: $SERVER_SCRIPT（若未检出子仓，请先运行 bash scripts/workspace.sh sync）"
    exit 1
  fi
}

ensure_web_repo() {
  if [[ ! -d "$ADMIN_WEB_DIR" || ! -f "$ADMIN_WEB_DIR/package.json" ]]; then
    log_err "未找到前端工程目录: $ADMIN_WEB_DIR（若未检出子仓，请先运行 bash scripts/workspace.sh sync）"
    exit 1
  fi
}

invoke_server() {
  local subcmd="$1"
  shift
  ensure_server_repo

  local srv_port
  srv_port="$(resolve_server_port)"
  local args=("$subcmd" "--log-dir" "$LOG_DIR" "--pid-dir" "$PID_DIR")

  case "$subcmd" in
    start|restart|check|status|stop)
      args+=("--port" "$srv_port")
      ;;
  esac

  case "$subcmd" in
    start|restart|check)
      args+=("--profile" "$OPT_PROFILE")
      [[ -n "$OPT_ENV_FILE" ]] && args+=("--env-file" "$OPT_ENV_FILE")
      [[ -n "$OPT_JAR" ]] && args+=("--jar" "$OPT_JAR")
      [[ "$OPT_JVM_OPTS_SET" == "true" ]] && args+=("--jvm-opts" "$OPT_JVM_OPTS")
      [[ "$OPT_SKIP_ENV_CHECK" == "true" ]] && args+=("--skip-env-check")
      ;;
  esac

  case "$subcmd" in
    start|restart)
      [[ "$OPT_BUILD" == "true" ]] && args+=("--build")
      [[ "$OPT_CLEAN" == "true" ]] && args+=("--clean")
      [[ "$OPT_WITH_TESTS" == "true" ]] && args+=("--with-tests")
      [[ -n "$OPT_START_TIMEOUT" ]] && args+=("--timeout" "$OPT_START_TIMEOUT")
      [[ "$OPT_SERVER_ARGS_SET" == "true" ]] && args+=("--app-args" "$OPT_SERVER_ARGS")
      ;;
  esac

  case "$subcmd" in
    start)
      [[ "$OPT_FG" == "true" ]] && args+=("--fg")
      ;;
    stop|restart)
      args+=("--stop-timeout" "$OPT_STOP_TIMEOUT")
      [[ "$OPT_FORCE" == "true" ]] && args+=("--force")
      ;;
    build)
      [[ "$OPT_CLEAN" == "true" ]] && args+=("--clean")
      [[ "$OPT_WITH_TESTS" == "true" ]] && args+=("--with-tests")
      ;;
    logs)
      args+=("-n" "$OPT_LINES")
      [[ "$OPT_FOLLOW" == "true" ]] && args+=("-f")
      [[ "$OPT_ERROR_LOG" == "true" ]] && args+=("--error")
      ;;
  esac

  if [[ "$subcmd" == "start" || "$subcmd" == "restart" ]] && [[ "$TARGET" == "server" ]] && [[ "${#TRAILING_ARGS[@]}" -gt 0 ]]; then
    bash "$SERVER_SCRIPT" "${args[@]}" "$@" "--" "${TRAILING_ARGS[@]}"
  else
    bash "$SERVER_SCRIPT" "${args[@]}" "$@"
  fi
}

read_web_state() {
  WEB_PID_FILE="$PID_DIR/admin-web.pid"
  WEB_META_FILE="$PID_DIR/admin-web.meta"
  WEB_LOG_FILE="$LOG_DIR/admin-web.log"

  WEB_STATE_PID=""
  WEB_STATE_WINPID=""
  WEB_STATE_PORT_PID=""
  WEB_STATE_PORT="$(resolve_web_port)"
  WEB_STATE_MODE="dev"
  WEB_STATE_LOG="$WEB_LOG_FILE"
  WEB_STATE_STARTED_AT=""

  if [[ -f "$WEB_PID_FILE" ]]; then
    WEB_STATE_PID="$(tr -d '[:space:]' < "$WEB_PID_FILE" || true)"
  fi
  if [[ -f "$WEB_META_FILE" ]]; then
    local val
    val="$(meta_get "$WEB_META_FILE" "WINPID")"
    [[ -n "$val" ]] && WEB_STATE_WINPID="$val"
    val="$(meta_get "$WEB_META_FILE" "PORT_PID")"
    [[ -n "$val" ]] && WEB_STATE_PORT_PID="$val"
    val="$(meta_get "$WEB_META_FILE" "PORT")"
    [[ -n "$val" ]] && WEB_STATE_PORT="$val"
    val="$(meta_get "$WEB_META_FILE" "MODE")"
    [[ -n "$val" ]] && WEB_STATE_MODE="$val"
    val="$(meta_get "$WEB_META_FILE" "LOG_FILE")"
    [[ -n "$val" ]] && WEB_STATE_LOG="$val"
    val="$(meta_get "$WEB_META_FILE" "STARTED_AT")"
    [[ -n "$val" ]] && WEB_STATE_STARTED_AT="$val"
  fi
}

clear_web_state() {
  rm -f "$PID_DIR/admin-web.pid" "$PID_DIR/admin-web.meta"
}

write_web_state() {
  local msys_pid="$1"
  local winpid="$2"
  local port_pid="$3"
  local port="$4"
  local mode="$5"
  local started_at
  started_at="$(date '+%Y-%m-%d %H:%M:%S')"

  mkdir -p "$PID_DIR"
  printf '%s\n' "$msys_pid" > "$PID_DIR/admin-web.pid"
  cat > "$PID_DIR/admin-web.meta" <<EOF
PID=$msys_pid
WINPID=$winpid
PORT_PID=$port_pid
PORT=$port
MODE=$mode
LOG_FILE=$LOG_DIR/admin-web.log
STARTED_AT=$started_at
EOF
}

check_web_toolchain() {
  if ! command -v node >/dev/null 2>&1; then
    log_err "未检测到 node 命令，请先安装 Node.js >= 22"
    return 1
  fi
  local node_ver node_major
  node_ver="$(node -v | tr -d '\r')"
  node_major="${node_ver#v}"
  node_major="${node_major%%.*}"
  if [[ "${node_major:-0}" -lt 22 ]]; then
    log_err "Node.js 版本过低（要求 >= 22，当前: $node_ver）"
    return 1
  fi
  log_ok "Node.js 基线就绪: $node_ver"

  if ! command -v pnpm >/dev/null 2>&1; then
    log_err "未检测到 pnpm 命令，请先安装 pnpm 11+"
    return 1
  fi
  log_ok "pnpm 基线就绪: v$(pnpm -v | tr -d '\r')"
}

check_web_deps() {
  if [[ ! -d "$ADMIN_WEB_DIR/node_modules" ]]; then
    log_err "未检测到 $ADMIN_WEB_DIR/node_modules，请先进入前端目录执行 pnpm install"
    return 1
  fi
  log_ok "前端依赖已安装 (node_modules)"
}

web_build() {
  ensure_web_repo
  check_web_toolchain
  check_web_deps

  cd "$ADMIN_WEB_DIR" || exit 1
  if [[ "$OPT_WITH_TESTS" == "true" ]]; then
    log_info "正在执行前端四合一质量门禁与构建 (typecheck + lint + test + build)..."
    pnpm typecheck && pnpm lint && pnpm test && pnpm build
  else
    log_info "正在构建前端生产产物 (pnpm build)..."
    pnpm build
  fi
  log_ok "admin-web 构建完成: $ADMIN_WEB_DIR/dist"
}

web_check() {
  ensure_web_repo
  printf "\n%b=== ateng-solid-admin-web 环境与配置巡检 ===%b\n" "${C_BOLD}" "${C_RESET}"
  local failed=false

  check_web_toolchain || failed=true
  check_web_deps || failed=true

  if [[ -f "$ADMIN_WEB_DIR/.env.local" ]]; then
    log_ok "已检测到本地环境覆写: .env.local"
  elif [[ -f "$ADMIN_WEB_DIR/.env.development" ]]; then
    log_ok "使用默认开发配置: .env.development（如需自定义代理可复制 .env.example 为 .env.local）"
  else
    log_warn "未检测到 .env.development 或 .env.local"
  fi

  local web_port proxy_target
  web_port="$(resolve_web_port)"
  proxy_target="$(resolve_web_proxy_target)"
  log_info "生效端口: $web_port | 开发代理目标: $proxy_target"

  read_web_state
  local port_pids
  port_pids="$(get_port_pids "$web_port" || true)"
  if [[ -n "$port_pids" ]]; then
    if [[ -n "$WEB_STATE_PID" ]] && is_pid_alive "$WEB_STATE_PID" "$WEB_STATE_WINPID"; then
      log_ok "端口 $web_port 由本脚本纳管前端监听中 (PID: $WEB_STATE_PID)"
    else
      log_warn "端口 $web_port 已被外部进程占用 (PID: $(printf '%s' "$port_pids" | tr '\n' ' '))"
    fi
  else
    log_ok "端口 $web_port 当前空闲可用"
  fi

  if [[ "$failed" == "true" ]]; then
    exit 1
  fi
}

web_start() {
  ensure_web_repo
  check_web_toolchain
  check_web_deps
  read_web_state

  local web_port
  web_port="$(resolve_web_port)"
  local run_mode="dev"
  if [[ "$OPT_PREVIEW" == "true" ]]; then
    run_mode="preview"
  fi

  # 1. 幂等检查
  if [[ -n "$WEB_STATE_PID" ]] && is_pid_alive "$WEB_STATE_PID" "$WEB_STATE_WINPID"; then
    local running_port="${WEB_STATE_PORT:-$web_port}"
    if is_port_listening "$running_port"; then
      log_ok "ateng-solid-admin-web 已在运行中 (PID: $WEB_STATE_PID | Mode: ${WEB_STATE_MODE:-dev} | Port: $running_port)"
      return 0
    fi
  fi

  if [[ -f "$WEB_PID_FILE" || -f "$WEB_META_FILE" ]]; then
    clear_web_state
  fi

  # 2. 端口占用拦截
  local existing_pids
  existing_pids="$(get_port_pids "$web_port" || true)"
  if [[ -n "$existing_pids" ]]; then
    log_err "前端端口 $web_port 已被其他进程占用 (PID: $(printf '%s' "$existing_pids" | tr '\n' ' '))，请先停止占用进程或改用 --web-port"
    exit 1
  fi

  # 3. 构建控制
  if [[ "$OPT_BUILD" == "true" ]]; then
    web_build
  elif [[ "$run_mode" == "preview" && ! -d "$ADMIN_WEB_DIR/dist" ]]; then
    log_info "preview 模式未检测到 dist 目录，自动执行前端构建..."
    web_build
  fi

  mkdir -p "$LOG_DIR" "$PID_DIR"
  local log_file="$LOG_DIR/admin-web.log"
  local cmd_args=()
  if [[ "$run_mode" == "preview" ]]; then
    cmd_args=("pnpm" "run" "preview" "--host" "--port" "$web_port")
  else
    cmd_args=("pnpm" "run" "dev" "--port" "$web_port")
    if [[ -d "$ADMIN_WEB_DIR/.yalc/@atengk" ]]; then
      local has_force_arg=false
      local warg
      if [[ "${#RESOLVED_WEB_ARGS_ARR[@]}" -gt 0 ]]; then
        for warg in "${RESOLVED_WEB_ARGS_ARR[@]}"; do
          if [[ "$warg" == "--force" ]]; then
            has_force_arg=true
            break
          fi
        done
      fi
      if [[ "$has_force_arg" == "false" ]]; then
        cmd_args+=("--force")
      fi
    fi
  fi

  if [[ "${#RESOLVED_WEB_ARGS_ARR[@]}" -gt 0 ]]; then
    cmd_args+=("${RESOLVED_WEB_ARGS_ARR[@]}")
  fi

  log_info "正在启动 ateng-solid-admin-web (Mode: $run_mode | Port: $web_port)..."
  if [[ "${#RESOLVED_WEB_ARGS_ARR[@]}" -gt 0 ]]; then
    log_info "前端附加启动参数: ${RESOLVED_WEB_ARGS_ARR[*]}"
  fi

  if [[ "$OPT_FG" == "true" ]]; then
    log_info "当前为前台模式，按 Ctrl+C 停止前端服务"
    cd "$ADMIN_WEB_DIR" || exit 1
    exec "${cmd_args[@]}"
  fi

  (
    cd "$ADMIN_WEB_DIR" || exit 1
    nohup "${cmd_args[@]}" >> "$log_file" 2>&1 < /dev/null &
    printf '%s' "$!" > "$PID_DIR/.admin-web.spawn.pid"
  )

  local spawned_pid
  spawned_pid="$(cat "$PID_DIR/.admin-web.spawn.pid")"
  rm -f "$PID_DIR/.admin-web.spawn.pid"

  local winpid=""
  if is_windows; then
    winpid="$(get_winpid_for_msys_pid "$spawned_pid" || true)"
  fi

  write_web_state "$spawned_pid" "$winpid" "" "$web_port" "$run_mode"

  local timeout="${OPT_START_TIMEOUT:-30}"
  local elapsed=0
  local ready=false
  while [[ "$elapsed" -lt "$timeout" ]]; do
    # 注意：pnpm dev 启动期间如果父壳提前交接给子 node 进程，优先按端口监听与 PID 共同判定
    if is_port_listening "$web_port"; then
      ready=true
      break
    fi
    if ! is_pid_alive "$spawned_pid" "$winpid"; then
      log_err "前端进程启动过程中异常退出，最后 30 行日志 ($log_file)："
      [[ -f "$log_file" ]] && tail -n 30 "$log_file" >&2 || true
      clear_web_state
      exit 1
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done

  if [[ "$ready" != "true" ]]; then
    log_err "等待前端端口 $web_port 就绪超时 (${timeout}s)，正在清理并回显末尾日志："
    stop_process_tree "$spawned_pid" "$winpid" "" 5
    clear_web_state
    [[ -f "$log_file" ]] && tail -n 30 "$log_file" >&2 || true
    exit 1
  fi

  local port_pid
  port_pid="$(get_port_pids "$web_port" | head -n 1 || true)"
  write_web_state "$spawned_pid" "$winpid" "$port_pid" "$web_port" "$run_mode"

  log_ok "ateng-solid-admin-web 启动成功！"
  printf "  - 访问地址: http://localhost:%s\n" "$web_port"
  printf "  - 运行模式: %s\n" "$run_mode"
  printf "  - 进程标识: PID=%s%s\n" "$spawned_pid" "${port_pid:+ (LISTEN_PID=$port_pid)}"
  printf "  - 日志文件: %s\n" "$log_file"
}

is_managed_port_alive() {
  local port="$1"
  local expected_pid="${2:-}"
  [[ -n "$expected_pid" ]] || return 1
  local pids p
  pids="$(get_port_pids "$port" || true)"
  while IFS= read -r p; do
    [[ "$p" == "$expected_pid" ]] && return 0
  done <<< "$pids"
  return 1
}

web_stop() {
  read_web_state
  local target_port="${WEB_STATE_PORT:-$(resolve_web_port)}"

  if [[ -n "$WEB_STATE_PID" ]] && { is_pid_alive "$WEB_STATE_PID" "$WEB_STATE_WINPID" || is_managed_port_alive "$target_port" "$WEB_STATE_PORT_PID"; }; then
    log_info "正在停止 ateng-solid-admin-web (PID: $WEB_STATE_PID | Port: $target_port)..."
    stop_process_tree "$WEB_STATE_PID" "$WEB_STATE_WINPID" "$WEB_STATE_PORT_PID" "$OPT_STOP_TIMEOUT"
    clear_web_state

    # 若仍有子进程残留占住该端口且它曾属于本次启动的 PORT_PID，二次收尾
    local leftover_pids p
    leftover_pids="$(get_port_pids "$target_port" || true)"
    if [[ -n "$leftover_pids" ]] && [[ -n "$WEB_STATE_PORT_PID" ]]; then
      while IFS= read -r p; do
        [[ -n "$p" ]] || continue
        if [[ "$p" == "$WEB_STATE_PORT_PID" || "$OPT_FORCE" == "true" ]]; then
          if is_windows; then
            kill_windows_pid_tree "$p" true
          else
            kill -KILL "$p" 2>/dev/null || true
          fi
        fi
      done <<< "$leftover_pids"
    fi
    log_ok "ateng-solid-admin-web 已停止"
    return 0
  fi

  clear_web_state

  local external_pids
  external_pids="$(get_port_pids "$target_port" || true)"
  if [[ -z "$external_pids" ]]; then
    log_info "ateng-solid-admin-web 未运行（端口 $target_port 空闲）"
    return 0
  fi

  if [[ "$OPT_FORCE" != "true" ]]; then
    log_warn "未发现脚本纳管的前端 PID，但端口 $target_port 正被外部进程占用 (PID: $(printf '%s' "$external_pids" | tr '\n' ' '))；为避免误杀已跳过（强制清理请加 --force）"
    return 0
  fi

  log_warn "正在按 --force 强制清理前端端口 $target_port 上的外部进程: $(printf '%s' "$external_pids" | tr '\n' ' ')..."
  local p
  while IFS= read -r p; do
    [[ -n "$p" ]] || continue
    if is_windows; then
      kill_windows_pid_tree "$p" true
    else
      kill -TERM "$p" 2>/dev/null || true
    fi
  done <<< "$external_pids"
  sleep 1
  if ! is_windows; then
    local remain_pids
    remain_pids="$(get_port_pids "$target_port" || true)"
    while IFS= read -r p; do
      [[ -n "$p" ]] || continue
      kill -KILL "$p" 2>/dev/null || true
    done <<< "$remain_pids"
  fi
  if is_port_listening "$target_port"; then
    log_err "强制清理前端端口 $target_port 失败，请手动排查"
    exit 1
  fi
  log_ok "已强制释放前端端口 $target_port"
}

web_status() {
  read_web_state
  local target_port="${WEB_STATE_PORT:-$(resolve_web_port)}"
  local port_pids
  port_pids="$(get_port_pids "$target_port" || true)"

  printf "\n%b=== ateng-solid-admin-web Status ===%b\n" "${C_BOLD}" "${C_RESET}"
  if [[ -n "$WEB_STATE_PID" ]] && { is_pid_alive "$WEB_STATE_PID" "$WEB_STATE_WINPID" || is_managed_port_alive "$target_port" "$WEB_STATE_PORT_PID"; }; then
    local listen_desc="端口监听中"
    if ! is_port_listening "$target_port"; then
      listen_desc="启动中/端口未就绪"
    fi
    printf "%b[RUNNING]%b ateng-solid-admin-web [mode:%s | port:%s | pid:%s%s | %s]\n" \
      "${C_GREEN}" "${C_RESET}" "${WEB_STATE_MODE:-dev}" "$target_port" "$WEB_STATE_PID" \
      "${WEB_STATE_PORT_PID:+ | listen_pid:$WEB_STATE_PORT_PID}" "$listen_desc"
    printf "          url: http://localhost:%s\n" "$target_port"
    printf "          log: %s\n" "$WEB_STATE_LOG"
    if [[ -n "$WEB_STATE_STARTED_AT" ]]; then
      printf "          started: %s\n" "$WEB_STATE_STARTED_AT"
    fi
    return 0
  fi

  if [[ -n "$port_pids" ]]; then
    printf "%b[EXTERNAL]%b 端口 %s 被非脚本进程占用 (PID: %s)\n" \
      "${C_YELLOW}" "${C_RESET}" "$target_port" "$(printf '%s' "$port_pids" | tr '\n' ' ')"
    return 0
  fi

  printf "%b[STOPPED]%b ateng-solid-admin-web 未运行 (默认端口: %s)\n" "${C_CYAN}" "${C_RESET}" "$target_port"
}

web_logs() {
  local log_file="$LOG_DIR/admin-web.log"
  if [[ ! -f "$log_file" ]]; then
    log_warn "前端日志文件尚不存在: $log_file"
    exit 1
  fi
  if [[ "$OPT_FOLLOW" == "true" ]]; then
    log_info "正在追踪前端日志 (Ctrl+C 退出): $log_file"
    tail -n "$OPT_LINES" -f "$log_file"
  else
    tail -n "$OPT_LINES" "$log_file"
  fi
}

tail_stream_with_tag() {
  local tag="$1"
  local color="$2"
  local file="$3"
  local line
  while IFS= read -r line; do
    printf "%b[%s]%b %s\n" "$color" "$tag" "$C_RESET" "$line"
  done < <(tail -n "$OPT_LINES" -f "$file")
}

cmd_logs_all() {
  local srv_log="$LOG_DIR/server.log"
  if [[ "$OPT_ERROR_LOG" == "true" && -f "$LOG_DIR/ateng-solid-server-error.log" ]]; then
    srv_log="$LOG_DIR/ateng-solid-server-error.log"
  fi
  local web_log="$LOG_DIR/admin-web.log"

  local available_tags=()
  local available_files=()
  local available_colors=()

  if [[ -f "$srv_log" ]]; then
    available_tags+=("server")
    available_files+=("$srv_log")
    available_colors+=("${C_CYAN}")
  fi
  if [[ -f "$web_log" ]]; then
    available_tags+=("admin-web")
    available_files+=("$web_log")
    available_colors+=("${C_GREEN}")
  fi

  if [[ "${#available_files[@]}" -eq 0 ]]; then
    log_warn "暂未找到任何日志文件（期望路径: $LOG_DIR/{server,admin-web}.log）"
    exit 1
  fi

  if [[ "$OPT_FOLLOW" != "true" ]]; then
    local i
    for ((i = 0; i < ${#available_files[@]}; i++)); do
      printf "\n%b=== [%s] %s (last %s lines) ===%b\n" \
        "${C_BOLD}" "${available_tags[$i]}" "${available_files[$i]}" "$OPT_LINES" "${C_RESET}"
      tail -n "$OPT_LINES" "${available_files[$i]}"
    done
    return 0
  fi

  log_info "正在聚合追踪全部运行日志 (Ctrl+C 退出)..."
  local stream_pids=()
  local stream_winpids=()
  cleanup_log_streams() {
    local p wp
    if [[ "${#stream_winpids[@]}" -gt 0 ]]; then
      for wp in "${stream_winpids[@]}"; do
        [[ -n "$wp" ]] && kill_windows_pid_tree "$wp" true
      done
    fi
    if [[ "${#stream_pids[@]}" -gt 0 ]]; then
      for p in "${stream_pids[@]}"; do
        if ! is_windows && command -v pkill >/dev/null 2>&1; then
          pkill -TERM -P "$p" 2>/dev/null || true
        fi
        kill "$p" 2>/dev/null || true
      done
    fi
  }
  trap cleanup_log_streams INT TERM EXIT

  local i child_pid child_wp
  for ((i = 0; i < ${#available_files[@]}; i++)); do
    tail_stream_with_tag "${available_tags[$i]}" "${available_colors[$i]}" "${available_files[$i]}" &
    child_pid="$!"
    stream_pids+=("$child_pid")
    if is_windows; then
      child_wp="$(ps -W -p "$child_pid" 2>/dev/null | awk 'NR==2 {print $4}' || true)"
      [[ "$child_wp" =~ ^[0-9]+$ ]] && stream_winpids+=("$child_wp")
    fi
  done
  wait
  cleanup_log_streams
  trap - INT TERM EXIT
}

warn_proxy_port_mismatch() {
  local srv_port proxy_target proxy_port
  srv_port="$(resolve_server_port)"
  proxy_target="$(resolve_web_proxy_target)"
  # 提取形如 http://127.0.0.1:8080 的端口
  if [[ "$proxy_target" =~ :([0-9]+)(/.*)?$ ]]; then
    proxy_port="${BASH_REMATCH[1]}"
    if [[ "$proxy_port" != "$srv_port" ]]; then
      log_warn "当前后端端口 ($srv_port) 与前端代理 VITE_PROXY_TARGET ($proxy_target) 端口不一致，联调时请检查 ateng-solid-admin-web/.env.local"
    fi
  fi
}

cmd_start() {
  if [[ "$OPT_FG" == "true" && "$TARGET" == "all" ]]; then
    log_err "--fg 前台模式仅支持单服务调试，请明确指定 server 或 admin-web"
    exit 1
  fi

  case "$TARGET" in
    all)
      warn_proxy_port_mismatch
      invoke_server start
      web_start
      printf "\n%b全栈联调环境已就绪！%b\n" "${C_BOLD}" "${C_RESET}"
      printf "  - 管理后台入口: http://localhost:%s\n" "$(resolve_web_port)"
      printf "  - 后端服务地址: http://127.0.0.1:%s\n" "$(resolve_server_port)"
      printf "  - 聚合状态/日志: bash scripts/solid.sh status | bash scripts/solid.sh logs -f\n"
      ;;
    server)
      invoke_server start
      ;;
    admin-web)
      web_start
      ;;
  esac
}

cmd_stop() {
  case "$TARGET" in
    all)
      if [[ -d "$ADMIN_WEB_DIR" ]]; then
        web_stop
      fi
      if [[ -f "$SERVER_SCRIPT" ]]; then
        invoke_server stop
      fi
      ;;
    server)
      invoke_server stop
      ;;
    admin-web)
      web_stop
      ;;
  esac
}

cmd_restart() {
  if [[ "$OPT_FG" == "true" && "$TARGET" == "all" ]]; then
    log_err "--fg 前台模式仅支持单服务调试，请明确指定 server 或 admin-web"
    exit 1
  fi

  cmd_stop
  cmd_start
}

cmd_status() {
  case "$TARGET" in
    all)
      if [[ -f "$SERVER_SCRIPT" ]]; then
        invoke_server status
      else
        log_warn "ateng-solid-server 尚未检出"
      fi
      if [[ -d "$ADMIN_WEB_DIR" ]]; then
        web_status
      else
        log_warn "ateng-solid-admin-web 尚未检出"
      fi
      ;;
    server)
      invoke_server status
      ;;
    admin-web)
      web_status
      ;;
  esac
}

cmd_logs() {
  case "$TARGET" in
    all)
      cmd_logs_all
      ;;
    server)
      invoke_server logs
      ;;
    admin-web)
      web_logs
      ;;
  esac
}

cmd_build() {
  case "$TARGET" in
    all)
      invoke_server build
      web_build
      ;;
    server)
      invoke_server build
      ;;
    admin-web)
      web_build
      ;;
  esac
}

cmd_check() {
  case "$TARGET" in
    all)
      local srv_ok=true
      local web_ok=true
      if [[ -f "$SERVER_SCRIPT" ]]; then
        invoke_server check || srv_ok=false
      else
        log_warn "ateng-solid-server 尚未检出"
      fi
      if [[ -d "$ADMIN_WEB_DIR" ]]; then
        web_check || web_ok=false
      else
        log_warn "ateng-solid-admin-web 尚未检出"
      fi
      if [[ "$srv_ok" != "true" || "$web_ok" != "true" ]]; then
        exit 1
      fi
      ;;
    server)
      invoke_server check
      ;;
    admin-web)
      web_check
      ;;
  esac
}

normalize_target() {
  case "$1" in
    all) printf 'all' ;;
    server|srv|backend) printf 'server' ;;
    admin-web|web|admin|frontend) printf 'admin-web' ;;
    *) return 1 ;;
  esac
}

parse_args() {
  local normalized_args=()
  local passthrough_seen=false
  while [[ "$#" -gt 0 ]]; do
    if [[ "$passthrough_seen" == "true" ]]; then
      normalized_args+=("$1")
      shift
      continue
    fi
    case "$1" in
      --)
        passthrough_seen=true
        normalized_args+=("--")
        shift
        ;;
      -p=*|--profile=*|--server-port=*|--web-port=*|--port=*|--env-file=*|--jar=*|--jvm-opts=*|--server-args=*|--web-args=*|--timeout=*|--stop-timeout=*|-n=*|--lines=*)
        normalized_args+=("${1%%=*}" "${1#*=}")
        shift
        ;;
      *)
        normalized_args+=("$1")
        shift
        ;;
    esac
  done

  if [[ "${#normalized_args[@]}" -gt 0 ]]; then
    set -- "${normalized_args[@]}"
  else
    set --
  fi

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --)
        shift
        while [[ "$#" -gt 0 ]]; do
          TRAILING_ARGS+=("$1")
          shift
        done
        break
        ;;
      start|stop|restart|status|logs|build|check|help)
        if [[ -z "$ACTION" ]]; then
          ACTION="$1"
          shift
        else
          log_err "重复或位置错误的子命令: $1"
          exit 1
        fi
        ;;
      all|server|srv|backend|admin-web|web|admin|frontend)
        if [[ -z "$TARGET" ]]; then
          TARGET="$(normalize_target "$1")"
          shift
        else
          log_err "重复指定的目标参数: $1"
          exit 1
        fi
        ;;
      -p|--profile)
        [[ "$#" -ge 2 ]] || { log_err "$1 缺少参数"; exit 1; }
        OPT_PROFILE="$2"
        [[ -n "$OPT_PROFILE" ]] || { log_err "--profile 缺少参数"; exit 1; }
        shift 2
        ;;
      --server-port)
        [[ "$#" -ge 2 ]] || { log_err "--server-port 缺少参数"; exit 1; }
        OPT_SERVER_PORT="$2"
        is_positive_int "$OPT_SERVER_PORT" || { log_err "--server-port 必须为正整数: $OPT_SERVER_PORT"; exit 1; }
        shift 2
        ;;
      --web-port)
        [[ "$#" -ge 2 ]] || { log_err "--web-port 缺少参数"; exit 1; }
        OPT_WEB_PORT="$2"
        is_positive_int "$OPT_WEB_PORT" || { log_err "--web-port 必须为正整数: $OPT_WEB_PORT"; exit 1; }
        shift 2
        ;;
      --port)
        [[ "$#" -ge 2 ]] || { log_err "--port 缺少参数"; exit 1; }
        OPT_SINGLE_PORT="$2"
        is_positive_int "$OPT_SINGLE_PORT" || { log_err "--port 必须为正整数: $OPT_SINGLE_PORT"; exit 1; }
        shift 2
        ;;
      --env-file)
        [[ "$#" -ge 2 ]] || { log_err "--env-file 缺少路径参数"; exit 1; }
        OPT_ENV_FILE="$2"
        [[ -n "$OPT_ENV_FILE" ]] || { log_err "--env-file 缺少路径参数"; exit 1; }
        shift 2
        ;;
      --jar)
        [[ "$#" -ge 2 ]] || { log_err "--jar 缺少路径参数"; exit 1; }
        OPT_JAR="$2"
        [[ -n "$OPT_JAR" ]] || { log_err "--jar 缺少路径参数"; exit 1; }
        shift 2
        ;;
      --jvm-opts)
        [[ "$#" -ge 2 ]] || { log_err "--jvm-opts 缺少参数值"; exit 1; }
        OPT_JVM_OPTS="$2"
        OPT_JVM_OPTS_SET=true
        shift 2
        ;;
      --server-args)
        [[ "$#" -ge 2 ]] || { log_err "--server-args 缺少参数值"; exit 1; }
        OPT_SERVER_ARGS="$2"
        OPT_SERVER_ARGS_SET=true
        shift 2
        ;;
      --web-args)
        [[ "$#" -ge 2 ]] || { log_err "--web-args 缺少参数值"; exit 1; }
        OPT_WEB_ARGS="$2"
        OPT_WEB_ARGS_SET=true
        shift 2
        ;;
      --build)
        OPT_BUILD=true
        shift
        ;;
      --clean)
        OPT_CLEAN=true
        shift
        ;;
      --with-tests)
        OPT_WITH_TESTS=true
        shift
        ;;
      --preview)
        OPT_PREVIEW=true
        shift
        ;;
      --fg)
        OPT_FG=true
        shift
        ;;
      --force)
        OPT_FORCE=true
        shift
        ;;
      --skip-env-check)
        OPT_SKIP_ENV_CHECK=true
        shift
        ;;
      --timeout)
        [[ "$#" -ge 2 ]] || { log_err "--timeout 缺少参数"; exit 1; }
        OPT_START_TIMEOUT="$2"
        is_positive_int "$OPT_START_TIMEOUT" || { log_err "--timeout 必须为正整数: $OPT_START_TIMEOUT"; exit 1; }
        shift 2
        ;;
      --stop-timeout)
        [[ "$#" -ge 2 ]] || { log_err "--stop-timeout 缺少参数"; exit 1; }
        OPT_STOP_TIMEOUT="$2"
        is_positive_int "$OPT_STOP_TIMEOUT" || { log_err "--stop-timeout 必须为正整数: $OPT_STOP_TIMEOUT"; exit 1; }
        shift 2
        ;;
      -f|--follow)
        OPT_FOLLOW=true
        shift
        ;;
      -n|--lines)
        [[ "$#" -ge 2 ]] || { log_err "$1 缺少参数"; exit 1; }
        OPT_LINES="$2"
        is_positive_int "$OPT_LINES" || { log_err "--lines 必须为正整数: $OPT_LINES"; exit 1; }
        shift 2
        ;;
      --error)
        OPT_ERROR_LOG=true
        shift
        ;;
      -h|--help)
        ACTION="help"
        shift
        ;;
      *)
        log_err "未知参数: $1"
        show_help
        exit 1
        ;;
    esac
  done

  if [[ -z "$ACTION" ]]; then
    ACTION="help"
  fi
  if [[ -z "$TARGET" ]]; then
    TARGET="all"
  fi
  if [[ -n "$OPT_SINGLE_PORT" && "$TARGET" == "all" ]]; then
    log_err "目标为 all 时请使用 --server-port 或 --web-port 区分端口，不要混用 --port"
    exit 1
  fi
}

parse_args "$@"
validate_runtime_args

case "$ACTION" in
  start) cmd_start ;;
  stop) cmd_stop ;;
  restart) cmd_restart ;;
  status) cmd_status ;;
  logs) cmd_logs ;;
  build) cmd_build ;;
  check) cmd_check ;;
  help) show_help ;;
esac
