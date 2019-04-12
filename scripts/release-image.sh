#!/bin/bash
set -euxo pipefail

repodir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)/.."

source "${repodir}/scripts/_common.sh"
source "${repodir}/version.txt"

#todo: for aws only
#bin/plume prerelease
#    --debug \
#    --platform=aws \
#    --aws-credentials="${AWS_CREDENTIALS}" \
#    --gce-json-key="${GOOGLE_APPLICATION_CREDENTIALS}" \
#    --channel="${CHANNEL}" \
#    --version="${COREOS_VERSION_ID}" \
#    --write-image-list=images.json \
#    --verify-key="${GPG_PUBLIC_KEY}"

log "running plume release"
BUILDS_BUCKET=${BUILDS_BUCKET#gs://} \
IMAGES_BUCKET=${RELEASE_BUCKET#gs://} \
GCE_PROJECT=datadog-sandbox \
bin/plume release \
    --debug \
    --gce-json-key="${GOOGLE_APPLICATION_CREDENTIALS}" \
    --version="${COREOS_VERSION}" \
    --channel="ddos-${CHANNEL}" \
    2>&1

#TODO download zip and use it to create signed update
#mkdir src/secrets
#cp secret-key src/secrets/key-1
#cp public-key src/secrets/pubkey-1

#./core_sign_update --image /mnt/host/source/src/build/images/amd64-usr/latest/coreos_production_update.bin --private_keys ../secrets/gpg-private-key:../secrets/gpg-private-key  --public_keys ../secrets/gpg-public-key:../secrets/gpg-public-key --kernel /mnt/host/source/src/build/images/amd64-usr/latest/coreos_production_image.vmlinuz

#TODO build the update.gz with core_sign_upload or whatever it is
#TODO updateservicectl to push to coreroller
