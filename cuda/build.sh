#!/bin/sh

CUDA_MAJOR=12
CUDA_MINOR=6
CUDA_REVISION=3
UBUNTU_VERSION=24.04

for artifact in cuda-minimal-build cuda-devel cuda-nsight-compute; do
  podman build \
    --target "$artifact" \
    --build-arg="CUDA_MAJOR=$CUDA_MAJOR" \
    --build-arg="CUDA_MINOR=$CUDA_MINOR" \
    --build-arg="CUDA_REVISION=$CUDA_REVISION" \
    --build-arg="UBUNTU_VERSION=$UBUNTU_VERSION" \
    --platform linux/amd64 . \
    --tag caffe3/$artifact:12.6.3
done
