#!/bin/sh
set -eu

fail() { printf 'Nastart Agent: %s\n' "$*" >&2; exit 1; }

[ "$(uname -s)" = Linux ] || fail '请在 NAS 或 Linux 主机的 SSH 终端执行。'
command -v curl >/dev/null || fail '需要 curl 来检查 HTTPS 服务。'

port=8787
namespace=changlwtju
container=nastart-agent
proxy=nastart-agent-proxy
owner_label=io.nastart.installer
owner=one-line-v1
data_volume=nastart-agent-bootstrap-data
proxy_volume=nastart-agent-bootstrap-proxy
native_dir=/opt/nastart-agent-native
native_data=/var/lib/nastart-agent
unit=nastart-agent-native.service
unit_path=/etc/systemd/system/$unit
spk_url=https://nastart.lagransun.cn/nastart-agent.spk
is_dsm=false
if [ -f /etc.defaults/VERSION ] && [ -d /var/packages ]; then is_dsm=true; fi

version_from_source() {
    LC_ALL=C sed -n 's/^AGENT_VERSION[[:space:]]*=[[:space:]]*"\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\)"[[:space:]]*$/\1/p' "$1"
}

if command -v nastart_release_payload >/dev/null 2>&1; then
    version=$nastart_release_version
else
    source_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../agent" && pwd) || fail '找不到 Agent 源码。请重新下载官网安装脚本。'
    version=$(version_from_source "$source_dir/nastart_agent.py")
fi
case "$version" in ''|*[!0-9.]*) fail 'Agent 版本无法识别。';; esac
image=$namespace/nastart-agent:$version

probe() {
    # Local unauthenticated health check. A fresh Agent uses its own certificate.
    curl --proto '=https' --insecure --noproxy '*' --silent --fail --max-time 3 \
        "https://127.0.0.1:$port/healthz" 2>/dev/null
}

verify_health() {
    retries=30
    while [ "$retries" -gt 0 ]; do
        response=$(probe) || response=
        if [ "$response" = "{\"ok\":true,\"version\":\"$version\"}" ]; then return; fi
        if [ -n "$response" ]; then fail "端口 $port 已有服务，或当前 Agent 版本与 $version 不一致。请通过原部署方式升级。"; fi
        retries=$((retries - 1))
        sleep 2
    done
    fail "HTTPS /healthz 未确认 Agent $version。请检查服务日志与端口 $port。"
}

require_free_agent_endpoint() {
    if probe >/dev/null; then fail "端口 $port 已有 HTTPS 服务。请先确认已有 Agent 的部署方式。"; fi
}

docker_owns_container() {
    actual=$(docker inspect --type container --format "{{index .Config.Labels \"$owner_label\"}}" "$1" 2>/dev/null) || return 1
    [ "$actual" = "$owner" ]
}

docker_container_exists() { docker inspect --type container --format '{{.Id}}' "$1" >/dev/null 2>&1; }

docker_reuse_volume() {
    if ! docker volume inspect "$1" >/dev/null 2>&1; then
        docker volume create --label "$owner_label=$owner" "$1" >/dev/null || fail "无法创建数据卷 $1。"
    fi
    label=$(docker volume inspect --format "{{index .Labels \"$owner_label\"}}" "$1")
    [ "$label" = "$owner" ] || fail "数据卷 $1 已由其他部署占用。"
}

report_docker() {
    printf 'Agent %s 已通过 HTTPS 自检。局域网地址为 https://NAS的局域网地址:%s\n' "$version" "$port"
    printf '查看当前配对码与二维码：docker exec %s python3 /app/nastart_agent.py show-config%s --address https://NAS的局域网地址:%s\n' "$1" "$2" "$port"
}

install_docker() {
    if [ -n "${DOCKER_HOST:-}" ] && [ -z "${DOCKER_CONTEXT:-}" ]; then
        endpoint=$DOCKER_HOST
    else
        context=$(docker context show) || fail '无法确定当前 Docker context。'
        endpoint=$(docker context inspect "$context" --format '{{.Endpoints.docker.Host}}') || fail '无法读取 Docker context。'
    fi
    case "$endpoint" in unix:///*) docker_socket=${endpoint#unix://};; *) fail '请切换到本机 Unix socket 的 Docker context。';; esac
    case "$docker_socket" in *[!a-zA-Z0-9_./-]*) fail 'Docker socket 路径不能用于安全的容器挂载。';; esac
    [ -S "$docker_socket" ] || fail '找不到 Docker daemon socket。请启动 Docker 后重试。'
    unset DOCKER_CONTEXT
    export DOCKER_HOST="$endpoint"
    docker info >/dev/null 2>&1 || fail 'Docker daemon 不可用。请启动 Docker 或使用有 Docker 权限的账号重试。'
    spk=$(docker ps -aq --filter label=com.docker.compose.project=nastart-agent-spk --filter label=com.docker.compose.service=agent) || fail '无法检查 DSM SPK。'
    if [ -n "$spk" ]; then
        case "$spk" in *[!a-f0-9]*) fail '发现多个 DSM Agent 容器，请在套件中心核对。';; esac
        verify_health
        report_docker "$spk" ' --data-dir /data/container-data'
        return
    fi
    if docker_container_exists "$container" && ! docker_owns_container "$container"; then
        verify_health
        report_docker "$container" ''
        return
    fi
    if [ -e "$unit_path" ]; then fail "已存在原生 systemd Agent。请继续使用 $unit，避免两套部署占用同一端口。"; fi

    for name in "$container" "$proxy"; do
        if docker_container_exists "$name"; then
            docker_owns_container "$name" || fail "容器 $name 已由其他部署占用。"
            installed=$(docker inspect --type container --format '{{.Config.Image}}' "$name")
            [ "$installed" = "$image" ] || fail "$name 由 $installed 管理。请用原部署方式升级并保留数据卷。"
        fi
    done
    if ! docker_container_exists "$container"; then require_free_agent_endpoint; fi
    if ! docker image inspect "$image" >/dev/null 2>&1; then
        docker pull "$image" || fail "无法拉取 $image，请检查网络和 NAS 架构。"
    fi
    docker_reuse_volume "$data_volume"
    docker_reuse_volume "$proxy_volume"
    if docker_container_exists "$proxy"; then
        docker start "$proxy" >/dev/null || fail '无法启动现有的 Agent 过滤代理。'
    else
        docker run -d --name "$proxy" --label "$owner_label=$owner" --restart unless-stopped \
            --network none --read-only --user root --cap-drop ALL --security-opt no-new-privileges:true --tmpfs /data \
            -v "$docker_socket:/var/run/docker.sock:ro" -v "$proxy_volume:/run/nastart-proxy" \
            --entrypoint python3 "$image" /app/docker_socket_proxy.py >/dev/null || fail '无法创建 Agent 过滤代理。'
    fi
    if docker_container_exists "$container"; then
        docker start "$container" >/dev/null || fail '无法启动现有 Agent 容器。'
    else
        provider=generic-linux
        if "$is_dsm"; then provider=synology; fi
        docker run -d --name "$container" --label "$owner_label=$owner" --restart unless-stopped \
            --read-only --cap-drop ALL --security-opt no-new-privileges:true --tmpfs /tmp:size=16m,mode=1777 \
            -p "$port:8787" -v "$data_volume:/data" -v "$proxy_volume:/run/nastart-proxy:ro" \
            -e "NASTART_PROVIDER_HINT=$provider" -e NASTART_DOCKER_SOCKET=/run/nastart-proxy/docker.sock \
            --health-cmd 'python3 -c "from nastart_agent import loopback_healthcheck; raise SystemExit(not loopback_healthcheck())"' \
            --health-interval 5s --health-timeout 3s "$image" >/dev/null || fail '无法创建 Agent 容器，请检查 TCP 8787。'
    fi
    verify_health
    report_docker "$container" ''
}

install_native() {
    [ -d /run/systemd/system ] && command -v systemctl >/dev/null || fail '未发现 Docker，也未发现正在运行的 systemd。'
    if [ "$(id -u)" -ne 0 ]; then
        command -v sudo >/dev/null || fail '原生 systemd 路径需要管理员权限。'
        exec sudo /bin/sh "$0"
    fi
    for dependency in python3 openssl flock install tar base64; do
        command -v "$dependency" >/dev/null || fail "原生 systemd 路径需要 $dependency。"
    done
    python=$(command -v python3)
    case "$python" in /*) :;; *) fail '无法找到 Python 3 可执行文件。';; esac
    case "$python" in *[!a-zA-Z0-9_./-]*) fail 'Python 3 路径包含 systemd 不支持的字符。';; esac
    "$python" -c 'import sys; sys.exit(sys.version_info < (3, 10))' || fail '需要 Python 3.10 或更新版本。'

    umask 077
    exec 9>/run/nastart-agent-native-install.lock
    flock -n 9 || fail '已有 Nastart Agent 安装正在执行。'
    if [ -e "$unit_path" ]; then
        grep -qx '# Managed by Nastart install_agent.sh' "$unit_path" || fail "$unit 已由其他部署使用。"
        installed=$(version_from_source "$native_dir/nastart_agent.py")
        [ "$installed" = "$version" ] || fail "已安装原生 Agent $installed。请使用保留 $native_data 的升级流程。"
    else
        if [ -e /etc/systemd/system/nastart-agent.service ]; then fail '已存在 Docker Compose 的 Nastart systemd 服务，请通过原部署方式启动。'; fi
        require_free_agent_endpoint
        work=$(mktemp -d)
        trap 'rm -rf "$work"' 0
        trap 'exit 1' HUP INT TERM
        if command -v nastart_release_payload >/dev/null 2>&1; then
            nastart_release_payload | base64 -d > "$work/payload.tar.gz" || fail '下载的内置 Agent 内容损坏。'
            tar -xzf "$work/payload.tar.gz" -C "$work" || fail '无法解开内置 Agent 内容。'
        else
            for name in nastart_agent.py qrencoder.py qrencoder-LICENSE.txt; do cp "$source_dir/$name" "$work/$name"; done
        fi
        [ "$(version_from_source "$work/nastart_agent.py")" = "$version" ] || fail '内置 Agent 版本与安装脚本不一致。'
        install -d -m 0755 "$native_dir"
        for name in nastart_agent.py qrencoder.py qrencoder-LICENSE.txt; do install -m 0644 "$work/$name" "$native_dir/$name"; done
        cat > "$work/$unit" <<EOF
# Managed by Nastart install_agent.sh
[Unit]
Description=Nastart Agent (native)
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
DynamicUser=yes
StateDirectory=nastart-agent
StateDirectoryMode=0700
UMask=0077
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes
Environment=NASTART_DOCKER_SOCKET=/run/nastart-no-docker.sock
ExecStart=$python $native_dir/nastart_agent.py --host 0.0.0.0 --port $port --data-dir $native_data
Restart=on-failure
RestartSec=3s

[Install]
WantedBy=multi-user.target
EOF
        install -m 0644 "$work/$unit" "$unit_path.pending"
        mv -f "$unit_path.pending" "$unit_path"
    fi
    systemctl daemon-reload || fail 'systemd 无法重新加载服务定义。'
    systemctl enable --now "$unit" || fail "无法启动 $unit。请运行 journalctl -u $unit。"
    verify_health
    printf 'Agent %s 已通过 HTTPS 自检。局域网地址为 https://NAS的局域网地址:%s\n' "$version" "$port"
    printf '查看当前配对码与二维码：sudo %s %s/nastart_agent.py show-config --data-dir %s --address https://NAS的局域网地址:%s\n' "$python" "$native_dir" "$native_data" "$port"
}

if command -v docker >/dev/null 2>&1; then
    install_docker
elif "$is_dsm"; then
    fail "DSM 未发现 Docker。请先在套件中心安装 Container Manager，再手动安装 $spk_url。"
else
    install_native
fi
