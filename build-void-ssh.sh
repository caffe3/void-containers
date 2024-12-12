#!/bin/sh

COMMIT=$(git describe --long --dirty --abbrev=10 --tags --always)

LIBC=${1:-glibc}

podman build \
  --target "image-user-void-ssh-tini" \
  --build-arg="LIBC=${LIBC}" \
  --platform linux/amd64 . \
	--tag caffe3/void-ssh-tini-${LIBC}:${COMMIT} \
  --output type=tar,dest=void-ssh-tini-${LIBC}.${COMMIT}.tar

