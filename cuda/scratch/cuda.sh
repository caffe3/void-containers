#!/bin/sh

CUDA_MAJOR=12
CUDA_MINOR=6
CUDA_REVISION=3

for a in cuda-minimal-build cuda-devel cuda-nsight-compute; do
  podman build \
    --target "$a" \
    --build-arg="CUDA_MAJOR=$CUDA_MAJOR" \
    --build-arg="CUDA_MINOR=$CUDA_MINOR" \
    --build-arg="CUDA_REVISION=$CUDA_REVISION" \
    --platform linux/amd64 . \
    --tag caffe3/$a:12.6.3
done
