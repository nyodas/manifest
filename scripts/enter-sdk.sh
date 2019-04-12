#!/bin/bash
set -euo pipefail

repodir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)/.."

source "${repodir}/scripts/_common.sh"
source "${repodir}/version.txt"

cleanup() {
	log "cleaning up"

	teardown_gcsproxy
}
trap cleanup exit

log "setting up gcsproxy"
setup_gcsproxy

log "running cork enter"
bin/cork enter -- \
    COREOS_DEV_BUILDS=${COREOS_DEV_BUILDS} \
    "${@:-/bin/bash}"
