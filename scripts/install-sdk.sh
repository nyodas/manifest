#!/bin/bash
set -euo pipefail

repodir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)/.."

source "${repodir}/scripts/_common.sh"
source "${repodir}/version.txt"

log "configuring repo to use local checkout"
mkdir -p .repo
ln -sfT .. .repo/manifests
ln -sfT ../.git .repo/manifests.git

git config --global color.ui true
git config --global user.name "buildbot"
git config --global user.email "buildbot"

mkdir -p bin

test -x bin/gcsproxy || {
	log "installing gcsproxy"
	curl -fsSL -o bin/gcsproxy https://github.com/daichirata/gcsproxy/releases/download/v0.2.0/gcsproxy_0.2.0_amd64_linux
	chmod +x bin/gcsproxy
}

log "setting up gcsproxy"
trap teardown_gcsproxy exit
setup_gcsproxy

test -x bin/cork || {
	log "installing cork"
	curl -fsSL -o bin/cork http://localhost:${GCSPROXY_PORT}/${TOOLS_BUCKET#gs://}/mantle-${MANTLE_VERSION#v}/cork
	chmod +x bin/cork
}

test -x bin/plume || {
	log "installing plume"
	curl -fsSL -o bin/plume http://localhost:${GCSPROXY_PORT}/${TOOLS_BUCKET#gs://}/mantle-${MANTLE_VERSION#v}/plume
	chmod +x bin/plume
}

log "determining correct manifest file for branch"
manifest_url="$(git remote get-url origin)"
manifest_branch="$(git rev-parse HEAD)"

if git symbolic-ref HEAD 2>&1 >/dev/null; then
	branch_ref="$(git symbolic-ref HEAD)"
elif git describe --exact-match --tags HEAD 2>&1 >/dev/null; then
	branch_ref="refs/tags/$(git tag --points-at HEAD | sort -Vr | head -n1)"
else
	branch_ref="$(git rev-parse HEAD)"
fi

case ${branch_ref} in
	refs/heads/build-*)
		manifest_name="${branch_ref#refs/heads/}.xml" ;;
	refs/tags/v*)
		manifest_name="build-$(sed -E "s,v(.*)\..*\..*,\1,g" <<<"${branch_ref#refs/tags/}").xml" ;;
	*)
		manifest_name="default.xml" ;;
esac

log "running cork create"
SDK_URL_HOST="localhost:${GCSPROXY_PORT}" \
SDK_URL_PATH="/${BUILDS_BUCKET#gs://}/sdk" \
bin/cork create \
	--verbose \
	--replace \
	--manifest-url "${manifest_url}" \
	--manifest-name "${manifest_name}" \
	--manifest-branch "${manifest_branch}" \
	--sdk-version "${COREOS_SDK_VERSION}" \
	--verify-key "${GPG_PUBLIC_KEY}" \
2>&1

log "running ./setup_board"
bin/cork enter -- \
	COREOS_DEV_BUILDS=${COREOS_DEV_BUILDS} \
	./setup_board 2>&1
