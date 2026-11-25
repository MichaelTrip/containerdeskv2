#!/usr/bin/env bash
set -Eeuo pipefail

cache_dir=/home/runner/.cache/actcache
cache_limit_bytes=$((6 * 1024 * 1024 * 1024))
runner_was_active=false

if (( EUID != 0 )); then
    echo 'Run forgejo-runner-cleanup as root' >&2
    exit 1
fi

restart_runner() {
    if [[ "$runner_was_active" == true ]]; then
        systemctl start forgejo-runner.service
    fi
}
trap restart_runner EXIT

# Stop accepting jobs and let the runner finish its current jobs before
# touching its cache database or pruning Docker build data.
if systemctl is-active --quiet forgejo-runner.service; then
    runner_was_active=true
    systemctl stop forgejo-runner.service
fi

if [[ -d "$cache_dir" && ! -L "$cache_dir" ]]; then
    cache_bytes="$(du -sB1 "$cache_dir" | cut -f1)"
    if (( cache_bytes > cache_limit_bytes )); then
        old_cache="${cache_dir}.prune.$(date +%s)"
        mv -- "$cache_dir" "$old_cache"
        install -d -m 0755 -o runner -g runner "$cache_dir"
        rm -rf -- "$old_cache"
    fi
fi

# This does not remove tagged images or active containers on the shared host.
docker buildx prune --builder default --force --max-used-space 4gb
docker image prune --force --filter 'until=168h'
