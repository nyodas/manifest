#!/bin/bash

if [ "${VERBOSE:-}" == "true" ]; then
	set -x
fi

export TOOLS_BUCKET="${TOOLS_BUCKET:-gs://datadog-os-tools}"
export BUILDS_BUCKET="${BUILDS_BUCKET:-gs://datadog-os-builds}"
export RELEASE_BUCKET="${RELEASE_BUCKET:-gs://datadog-os-images}"

export MANTLE_VERSION="v0.0.0"

export GCSPROXY_PORT="${GCSPROXY_PORT:-8090}"
export COREOS_DEV_BUILDS="http://localhost:${GCSPROXY_PORT}/${BUILDS_BUCKET#gs://}"

log() {
	printf "\033[0;34m>>> \033[0;32m${@} \033[0m\n" >&2
}

fatal() {
	printf "\033[0;31m>>> ${@} \033[0m\n" >&2
	exit 1
}

setup_gcsproxy() {
	test -x bin/gcsproxy || fatal "bin/gcsproxy not found"

	bin/gcsproxy -v \
		-b "127.0.0.1:${GCSPROXY_PORT}"  2>gcsproxy.log &
	echo $! > gcsproxy.pid

	until curl -s "http://127.0.0.1:${GCSPROXY_PORT}" >/dev/null; do sleep 1; done;
	log "gcsproxy running on port ${GCSPROXY_PORT}"
}

teardown_gcsproxy() {
	test -f gcsproxy.pid && {
		kill $(cat gcsproxy.pid) || true
		rm -f gcsproxy.pid
	}
}

setup_gpg_signer() {
	gpg --import "${GPG_PRIVATE_KEY}"
}

teardown_gpg_signer() {
	gpg --batch --yes --delete-secret-keys "${GPG_KEY_FINGERPRINT}"
}

configure_github_push() {
	local repodir="${1}"

	export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-"ssh -o StrictHostKeyChecking=no"}"
	if test -f "${GITHUB_DEPLOY_KEY}"; then
		export GIT_SSH_COMMAND="${GIT_SSH_COOMMAND} -i ${GITHUB_DEPLOY_KEY}"
	fi

	git -C "${repodir}" config user.name "buildbot"
	git -C "${repodir}" config user.email "buildbot"
}
