# syntax=docker/dockerfile:1
FROM --platform=${BUILDPLATFORM} alpine:3.18 AS bootstrap
ARG TARGETPLATFORM
ARG MIRROR=https://repo-default.voidlinux.org
ARG LIBC
RUN apk add ca-certificates curl && \
  curl "${MIRROR}/static/xbps-static-static-0.59_5.$(uname -m)-musl.tar.xz" | tar vJx
COPY keys/* /target/var/db/xbps/keys/
COPY setup.sh /bootstrap/setup.sh
COPY noextract-python.conf /target/etc/xbps.d/noextract-python.conf
RUN --mount=type=cache,sharing=locked,target=/target/var/cache/xbps,id=repocache-${LIBC} \
  . /bootstrap/setup.sh; \
  XBPS_TARGET_ARCH=${ARCH} xbps-install -S \
    -R "${REPO}" \
    -r /target

FROM --platform=${BUILDPLATFORM} bootstrap AS install-default
ARG TARGETPLATFORM
ARG MIRROR
ARG LIBC
COPY --from=bootstrap /target /target
COPY noextract.conf /target/etc/xbps.d/noextract.conf
RUN --mount=type=cache,sharing=locked,target=/target/var/cache/xbps,id=repocache-${LIBC} \
  . /bootstrap/setup.sh; \
  XBPS_TARGET_ARCH=${ARCH} xbps-install -Sy \
    -R "${REPO}" \
    -r /target \
    xbps base-files dash coreutils grep run-parts sed gawk

FROM --platform=${BUILDPLATFORM} bootstrap AS install-busybox
ARG TARGETPLATFORM
ARG MIRROR
ARG LIBC
COPY --from=bootstrap /target /target
COPY noextract.conf /target/etc/xbps.d/noextract.conf
RUN --mount=type=cache,sharing=locked,target=/target/var/cache/xbps,id=repocache-${LIBC} \
  . /bootstrap/setup.sh; \
  XBPS_TARGET_ARCH=${ARCH} xbps-install -Sy \
    -R "${REPO}" \
    -r /target \
    xbps base-files busybox-huge

FROM --platform=${BUILDPLATFORM} bootstrap AS install-full
ARG TARGETPLATFORM
ARG MIRROR
ARG LIBC
COPY --from=bootstrap /target /target
RUN --mount=type=cache,sharing=locked,target=/target/var/cache/xbps,id=repocache-${LIBC} \
  . /bootstrap/setup.sh; \
  XBPS_TARGET_ARCH=${ARCH} xbps-install -Sy \
    -R "${REPO}" \
    -r /target \
    base-container

FROM scratch AS image-default
COPY --from=install-default /target /
RUN \
  install -dm1777 tmp; \
  xbps-reconfigure -fa; \
  rm -rf /var/cache/xbps/*

FROM scratch AS image-busybox
COPY --from=install-busybox /target /
RUN \
  for util in $(/usr/bin/busybox --list); do \
    [ ! -f "/usr/bin/$util" ] && /usr/bin/busybox ln -sfv busybox "/usr/bin/$util"; \
  done; \
  install -dm1777 tmp; \
  xbps-reconfigure -fa; \
  rm -rf /var/cache/xbps/*
CMD ["/bin/sh"]

FROM scratch AS image-full
COPY --from=install-full /target /
RUN \
  install -dm1777 tmp; \
  xbps-reconfigure -fa; \
  rm -rf /var/cache/xbps/*
CMD ["/bin/sh"]

FROM image-full AS image-full-ssh
RUN xbps-install -Sy openssh socklog socklog-void iproute2 iputils curl git bash && \
  xbps-remove -o
RUN mkdir -p /root/.ssh; \
  echo "echo \$PUBLIC_KEY > /root/.ssh/authorized_keys" > /etc/runit/core-services/06-ssh-root.sh; \
  cd /etc/runit/runsvdir/current && ln -s /etc/sv/sshd .
EXPOSE 22
CMD ["/sbin/runit-init"]

FROM image-full-ssh AS image-full-cuda-ssh
ARG CUDA_MAJOR
ARG CUDA_MINOR
ARG CUDA_REVISION
ARG UBUNTU_VERSION
RUN xbps-install -Sy apt dpkg gnupg
RUN mkdir -p /var/lib/dpkg
COPY --from=nvidia/cuda:${CUDA_MAJOR}.${CUDA_MINOR}.${CUDA_REVISION}-base-ubuntu${UBUNTU_VERSION} /etc/apt /etc/apt
COPY --from=nvidia/cuda:${CUDA_MAJOR}.${CUDA_MINOR}.${CUDA_REVISION}-base-ubuntu${UBUNTU_VERSION} /etc/debian_version /etc/debian_version
COPY --from=nvidia/cuda:${CUDA_MAJOR}.${CUDA_MINOR}.${CUDA_REVISION}-base-ubuntu${UBUNTU_VERSION} /usr/share/keyrings /usr/share/keyrings
RUN apt-get -y --no-install-recommends update
RUN apt-get -y --no-install-recommends install cuda-minimal-build-12-6
EXPOSE 22
CMD ["/sbin/runit-init"]

FROM image-full-cuda-ssh AS image-full-cuda-pytorch-ssh
ARG PYTORCH_VERSION
ARG CUDA_MAJOR
ARG CUDA_MINOR
RUN xbps-install -Sy python3 python3-pip python3-wheel
RUN pip3 --no-cache-dir install \
  nvidia-nvtx-cu${CUDA_MAJOR} \
  nvidia-nvjitlink-cu${CUDA_MAJOR} \
  nvidia-nccl-cu${CUDA_MAJOR} \
  nvidia-curand-cu${CUDA_MAJOR} \
  nvidia-cufft-cu${CUDA_MAJOR} \
  nvidia-cuda-runtime-cu${CUDA_MAJOR} \
  nvidia-cuda-nvrtc-cu${CUDA_MAJOR} \
  nvidia-cuda-cupti-cu${CUDA_MAJOR} \
  nvidia-cublas-cu${CUDA_MAJOR} \
  nvidia-cusparse-cu${CUDA_MAJOR} \
  nvidia-cudnn-cu${CUDA_MAJOR} \
  nvidia-cusolver-cu${CUDA_MAJOR} \
  --index-url https://download.pytorch.org/whl/nightly/cu${CUDA_MAJOR}${CUDA_MINOR}
RUN pip3 --no-cache-dir install \
  torch==${PYTORCH_VERSION}+cu${CUDA_MAJOR}${CUDA_MINOR} torchvision torchaudio \
  --index-url https://download.pytorch.org/whl/nightly/cu${CUDA_MAJOR}${CUDA_MINOR}
RUN xbps-install -Syu
EXPOSE 22
CMD ["/sbin/runit-init"]

FROM image-full-ssh AS image-full-builder
RUN useradd -G users -s /bin/sh -m void; \
  mkdir -p /home/void/.ssh; \
  echo "echo \$PUBLIC_KEY > /home/void/.ssh/authorized_keys" > /etc/runit/core-services/06-ssh-void.sh
RUN cd /home/void && \
  su void -c 'curl -L https://github.com/void-linux/void-packages/archive/refs/heads/master.tar.gz | tar zxf -'
RUN cd /home/void/void-packages-master && \
  su void -c './xbps-src binary-bootstrap'
EXPOSE 22
CMD ["/sbin/runit-init"]
