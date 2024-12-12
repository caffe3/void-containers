#!/bin/sh

COMMIT=$(git describe --long --dirty --abbrev=10 --tags --always)
#podman build --target "image-full-builder" --build-arg="LIBC=glibc" --platform linux/amd64 . \
#	--tag caffe3/void-builder:${COMMIT}
#podman tag caffe3/void-builder:${COMMIT} caffe3/void-builder:latest

#podman build \
#  --target "image-full-void-ssh-cuda-pytorch" \
#  --build-arg="LIBC=glibc" \
#  --build-arg="CUDA_MAJOR=12" \
#  --build-arg="CUDA_MINOR=6" \
#  --build-arg="CUDA_REVISION=3" \
#  --build-arg="UBUNTU_VERSION=24.04" \
#  --build-arg="PYTORCH_VERSION=2.6.0.dev20241209" \
#  --platform linux/amd64 . \
#	--tag caffe3/void-cuda-pytorch:${COMMIT}

podman build \
  --target "image-full-void-cuda" \
  --build-arg="LIBC=glibc" \
  --build-arg="CUDA_MAJOR=12" \
  --build-arg="CUDA_MINOR=6" \
  --build-arg="CUDA_REVISION=3" \
  --build-arg="UBUNTU_VERSION=24.04" \
  --build-arg="PYTORCH_VERSION=2.6.0.dev20241209" \
  --platform linux/amd64 . \
	--tag caffe3/void-cuda:${COMMIT}
