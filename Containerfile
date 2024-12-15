ARG LASTSET=-1
ARG IMAGETYPE=base

FROM --platform=${BUILDPLATFORM} alpine:3.21 AS prepare
ARG TARGETPLATFORM
ARG MIRROR=https://repo-ci.voidlinux.org
ARG LIBC
RUN apk add ca-certificates curl && \
  curl "${MIRROR}/static/xbps-static-static-0.59_5.$(uname -m)-musl.tar.xz" | tar vJx
COPY keys/* /target/var/db/xbps/keys/
COPY scripts/bootstrap/setup.sh /bootstrap/setup.sh
COPY --chmod=700 scripts/bootstrap/buildset.sh /bootstrap/buildset.sh
COPY xbps.d/noextract-python.conf /target/etc/xbps.d/noextract-python.conf

FROM --platform=${BUILDPLATFORM} prepare AS bootstrap
ARG TARGETPLATFORM
ARG MIRROR
ARG LIBC
RUN --mount=type=cache,sharing=locked,target=/target/var/cache/xbps,id=repocache-${LIBC} \
  . /bootstrap/setup.sh; \
  XBPS_TARGET_ARCH=${ARCH} xbps-install -S \
    -R "${REPO}" \
    -r /target

FROM --platform=${BUILDPLATFORM} bootstrap AS install-base
ARG TARGETPLATFORM
ARG MIRROR
ARG LIBC
ARG BASE
ARG BASEPKGS
COPY --from=bootstrap /target /target
COPY xbps.d/${BASE}.conf /target/etc/xbps.d/${BASE}.conf
RUN --mount=type=cache,sharing=locked,target=/target/var/cache/xbps,id=repocache-${LIBC} \
  . /bootstrap/setup.sh; \
  XBPS_TARGET_ARCH=${ARCH} xbps-install -y \
    -R "${REPO}" \
    -r /target \
    ${BASEPKGS}

FROM --platform=${BUILDPLATFORM} install-base AS install-populate-cache
ARG TARGETPLATFORM
ARG MIRROR
ARG LIBC
ARG ALLPKGS
RUN mkdir -p /set0 /set1 /set2
RUN --mount=type=cache,sharing=locked,target=/target/var/cache/xbps,id=repocache-${LIBC} \
  . /bootstrap/setup.sh; \
  XBPS_TARGET_ARCH=${ARCH} xbps-install -y -D \
    -R "${REPO}" \
    -r /target \
    ${ALLPKGS}

FROM --platform=${BUILDPLATFORM} install-populate-cache AS install-set0
ARG TARGETPLATFORM
ARG MIRROR
ARG LIBC
ARG SET0PKGS
RUN --network=none \
    --mount=type=cache,sharing=locked,target=/target/var/cache/xbps,id=repocache-${LIBC} \
    --mount=type=bind,from=install-base,source=/target,target=/base \
  . /bootstrap/setup.sh; \
  XBPS_TARGET_ARCH=${ARCH} \
  xbps-install -y \
    -R "${REPO}" \
    -r /target \
    ${SET0PKGS}
RUN --mount=type=bind,from=install-base,source=/target,target=/base \
  /bootstrap/buildset.sh /base /target /set0

FROM --platform=${BUILDPLATFORM} install-populate-cache AS install-set1
ARG TARGETPLATFORM
ARG MIRROR
ARG LIBC
ARG SET1PKGS
RUN --network=none \
    --mount=type=cache,sharing=locked,target=/target/var/cache/xbps,id=repocache-${LIBC} \
    --mount=type=bind,from=install-base,source=/target,target=/base \
  . /bootstrap/setup.sh; \
  XBPS_TARGET_ARCH=${ARCH} \
  xbps-install -y \
    -R "${REPO}" \
    -r /target \
    ${SET1PKGS}
RUN --mount=type=bind,from=install-base,source=/target,target=/base \
  /bootstrap/buildset.sh /base /target /set1

FROM --platform=${BUILDPLATFORM} install-populate-cache AS install-set2
ARG TARGETPLATFORM
ARG MIRROR
ARG LIBC
ARG SET2PKGS
RUN --network=none \
    --mount=type=cache,sharing=locked,target=/target/var/cache/xbps,id=repocache-${LIBC} \
    --mount=type=bind,from=install-base,source=/target,target=/base \
  . /bootstrap/setup.sh; \
  XBPS_TARGET_ARCH=${ARCH} \
  xbps-install -y \
    -R "${REPO}" \
    -r /target \
    ${SET2PKGS}
RUN --mount=type=bind,from=install-base,source=/target,target=/base \
  /bootstrap/buildset.sh /base /target /set2

FROM --platform=${BUILDPLATFORM} install-populate-cache AS set0
COPY --link --from=install-set0 /set0 /set0

FROM --platform=${BUILDPLATFORM} set0 AS set1
COPY --link --from=install-set1 /set1 /set1

FROM --platform=${BUILDPLATFORM} set1 AS set2
COPY --link --from=install-set2 /set2 /set2

FROM --platform=${BUILDPLATFORM} set${LASTSET} AS install-flavor
ARG TARGETPLATFORM
ARG MIRROR
ARG LIBC
ARG SETPKGS
RUN --network=none \
    --mount=type=cache,sharing=locked,target=/target/var/cache/xbps,id=repocache-${LIBC} \
  . /bootstrap/setup.sh; \
  XBPS_TARGET_ARCH=${ARCH} \
  xbps-install -y \
    -R "${REPO}" \
    -r /target \
    ${SETPKGS}

FROM install-${IMAGETYPE} AS install

FROM scratch AS image
ARG BASE
COPY --link --from=install-base /target /
COPY --link --from=install /set0 /
COPY --link --from=install /set1 /
COPY --link --from=install /set2 /
COPY --link --from=install /target/var/db/xbps /target/var/db/xbps
COPY scripts/post-$BASE.sh /post.sh
RUN \
  . /post.sh; \
  install -dm1777 tmp; \
  xbps-reconfigure -fa; \
  rm -rf /var/cache/xbps/*; \
  rm -f /post.sh
CMD ["/bin/sh"]
