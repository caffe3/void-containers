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

FROM image-full AS image-full-cuda
RUN xbps-install -Sy apt dpkg gnupg
RUN mkdir -p /var/lib/dpkg
COPY --from=nvidia/cuda:12.6.3-base-ubuntu24.04 /etc/apt /etc/apt
COPY --from=nvidia/cuda:12.6.3-base-ubuntu24.04 /etc/debian_version /etc/debian_version
COPY --from=nvidia/cuda:12.6.3-base-ubuntu24.04 /usr/share/keyrings /usr/share/keyrings
RUN apt-get -y --no-install-recommends update
RUN apt-get -y --no-install-recommends install cuda-minimal-build-12-6
CMD ["/bin/sh"]

FROM image-full-cuda AS image-full-cuda-pytorch
RUN xbps-install -Sy python3 python3-pip python3-wheel
RUN pip3 --no-cache-dir install \
  nvidia-nvtx-cu12 \
  nvidia-nvjitlink-cu12 \
  nvidia-nccl-cu12 \
  nvidia-curand-cu12 \
  nvidia-cufft-cu12 \
  nvidia-cuda-runtime-cu12 \
  nvidia-cuda-nvrtc-cu12 \
  nvidia-cuda-cupti-cu12 \
  nvidia-cublas-cu12 \
  nvidia-cusparse-cu12 \
  nvidia-cudnn-cu12 \
  nvidia-cusolver-cu12 \
  --index-url https://download.pytorch.org/whl/nightly/cu126
RUN pip3 --no-cache-dir install \
  torch torchvision torchaudio \
  --index-url https://download.pytorch.org/whl/nightly/cu126
CMD ["/bin/sh"]

FROM image-full AS image-full-ssh
RUN xbps-install -Sy openssh socklog socklog-void iproute2 iputils curl git bash && \
  xbps-remove -o
RUN mkdir -p /root/.ssh; \
  echo "echo \$PUBLIC_KEY > /root/.ssh/authorized_keys" > /etc/runit/core-services/06-ssh-root.sh; \
  cd /etc/runit/runsvdir/current && ln -s /etc/sv/sshd .
EXPOSE 22
ENTRYPOINT ["/sbin/runit-init"]

FROM image-full-cuda-pytorch AS image-full-cuda-pytorch-ssh
RUN xbps-install -Sy openssh socklog socklog-void iproute2 iputils curl git bash && \
  xbps-remove -o
RUN mkdir -p /root/.ssh; \
  echo "echo \$PUBLIC_KEY > /root/.ssh/authorized_keys" > /etc/runit/core-services/06-ssh-root.sh; \
  cd /etc/runit/runsvdir/current && ln -s /etc/sv/sshd .
EXPOSE 22
ENTRYPOINT ["/sbin/runit-init"]

FROM image-full-ssh AS image-full-builder
RUN useradd -G users -s /bin/sh -m void; \
  mkdir -p /home/void/.ssh; \
  echo "echo \$PUBLIC_KEY > /home/void/.ssh/authorized_keys" > /etc/runit/core-services/06-ssh-void.sh
RUN cd /home/void && \
  su void -c 'curl -L https://github.com/void-linux/void-packages/archive/refs/heads/master.tar.gz | tar zxf -'
RUN cd /home/void/void-packages-master && \
  su void -c './xbps-src binary-bootstrap'
