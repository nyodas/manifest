#!/bin/bash
set -euo pipefail

repodir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)/.."

source "${repodir}/scripts/_common.sh"
source "${repodir}/version.txt"

export COREOS_OFFICIAL="${COREOS_OFFICIAL:-1}"

cleanup() {
	log "cleaning up"

	teardown_gcsproxy
	teardown_gpg_signer
}
trap cleanup exit

log "setting up gcsproxy"
setup_gcsproxy

log "setting up gpg signer"
setup_gpg_signer

log "configure github push"
configure_github_push "${repodir}"

log "running emerge catalyst"
bin/cork enter -- \
	sudo emerge -uv --jobs=2 catalyst 2>&1

log "running ./bootstrap_sdk"
bin/cork enter -- \
	COREOS_DEV_BUILDS=${COREOS_DEV_BUILDS} \
	sudo -E ./bootstrap_sdk \
		--sign "${GPG_KEY_FINGERPRINT}" \
		--sign_digests "${GPG_KEY_FINGERPRINT}" \
		--upload --upload_root="${BUILDS_BUCKET}" \
		--version "${COREOS_VERSION}" \
	2>&1

log "running ./build_toolchains"
bin/cork enter -- \
	COREOS_DEV_BUILDS=${COREOS_DEV_BUILDS} \
	sudo -E ./build_toolchains \
		--sign "${GPG_KEY_FINGERPRINT}" \
		--sign_digests "${GPG_KEY_FINGERPRINT}" \
		--upload --upload_root="${BUILDS_BUCKET}" \
		--version "${COREOS_VERSION}" \
		2>&1

if [[ "${COREOS_OFFICIAL:-0}" -eq 1 ]]; then
	log "pushing sdk version update to refs/heads/sdk-${COREOS_VERSION_ID}"
	sed -i "${repodir}/version.txt" \
		-e "s/^COREOS_SDK_VERSION=.*$/COREOS_SDK_VERSION=${COREOS_VERSION_ID}/"

	git -C "${repodir}" add "${repodir}/version.txt"
	git -C "${repodir}" commit -m "version.txt: bump sdk version to ${COREOS_VERSION_ID}"
	git -C "${repodir}" push origin "HEAD:refs/heads/sdk-${COREOS_VERSION_ID}"
fi
