#!/bin/bash
set -euo pipefail

repodir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)/.."

source "${repodir}/scripts/_common.sh"
source "${repodir}/version.txt"

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

if [ "${COREOS_OFFICIAL:-}" == "1" ]; then
	log "running ./set_official"
	bin/cork enter -- \
		./set_official
fi

log "running ./build_packages"
bin/cork enter -- \
	COREOS_DEV_BUILDS=${COREOS_DEV_BUILDS} \
	./build_packages \
		--upload --upload_root "${BUILDS_BUCKET}" \
		--sign "${GPG_KEY_FINGERPRINT}" \
		--sign_digests "${GPG_KEY_FINGERPRINT}" \
	2>&1

log "running ./build_image"
bin/cork enter -- \
	COREOS_DEV_BUILDS=${COREOS_DEV_BUILDS} \
	./build_image prod \
		--group stable \
		--upload --upload_root "${BUILDS_BUCKET}" \
		--sign "${GPG_KEY_FINGERPRINT}" \
		--sign_digests "${GPG_KEY_FINGERPRINT}" \
	2>&1

for format in qemu gce ami_vmdk; do
	log "running ./image_to_vm.sh --format ${format}"
	bin/cork enter -- \
		COREOS_DEV_BUILDS=${COREOS_DEV_BUILDS} \
		./image_to_vm.sh \
			--getbinpkg \
			--format "${format}" \
			--from /mnt/host/source/src/build/images/amd64-usr/latest \
			--upload --upload_root "${BUILDS_BUCKET}" \
			--sign "${GPG_KEY_FINGERPRINT}" \
			--sign_digests "${GPG_KEY_FINGERPRINT}" \
			2>&1
done
