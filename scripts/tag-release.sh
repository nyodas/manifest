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

log "configuring github push"
configure_github_push "${repodir}"

log "calculating next version"
version_parts=( ${COREOS_VERSION_ID//./ } )
case ${RELEASE_TYPE} in
	major)
		major="$((${version_parts[0]} + 1))"
		minor="0"
		patch="0"
		push_target="HEAD:refs/heads/master"
		branch_arg="--nobranch"
		;;
	minor)
		major="${version_parts[0]}"
		minor="$((${version_parts[1]} + 1))"
		patch="0"
		branch_arg="--branch"
		;;
	*)
		echo "invalid release type ${RELEASE_TYPE}" >&2; exit 1;;
esac
push_target="${push_target:-} refs/heads/build-${major} refs/tags/v${major}.${minor}.${patch}"

log "running ./tag_release"
bin/cork enter -- \
	COREOS_DEV_BUILDS=${COREOS_DEV_BUILDS} \
	./tag_release \
		${branch_arg} \
		--signer "${GPG_KEY_FINGERPRINT}" \
		--branch_projects "''" \
		--sdk_version "keep" \
		--major "${major}" \
		--minor "${minor}" \
		--patch "${patch}" \
	2>&1

log "pushing release branch and tags"
git push origin ${push_target}
