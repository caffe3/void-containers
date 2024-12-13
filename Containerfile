# syntax=docker/dockerfile:1
FROM --platform=${BUILDPLATFORM} alpine:3.18 AS bootstrap
ARG TARGETPLATFORM
ARG MIRROR=https://repo-ci.voidlinux.org
ARG LIBC
RUN apk add ca-certificates curl && \
  curl "${MIRROR}/static/xbps-static-static-0.59_5.$(uname -m)-musl.tar.xz" | tar vJx
COPY keys/* /target/var/db/xbps/keys/
COPY scripts/bootstrap/setup.sh /bootstrap/setup.sh
COPY noextract-python.conf /target/etc/xbps.d/noextract-python.conf
RUN --mount=type=cache,sharing=locked,target=/target/var/cache/xbps,id=repocache-${LIBC} \
  . /bootstrap/setup.sh; \
  XBPS_TARGET_ARCH=${ARCH} xbps-install -S \
    -R "${REPO}" \
    -r /target

FROM --platform=${BUILDPLATFORM} bootstrap AS install
ARG TARGETPLATFORM
ARG MIRROR
ARG LIBC
ARG IMAGETYPE
ARG PACKAGES
COPY --from=bootstrap /target /target
COPY xbps.d/${IMAGETYPE}.conf /target/etc/xbps.d/${IMAGETYPE}.conf
RUN --mount=type=cache,sharing=locked,target=/target/var/cache/xbps,id=repocache-${LIBC} \
  . /bootstrap/setup.sh; \
  XBPS_TARGET_ARCH=${ARCH} xbps-install -y \
    -R "${REPO}" \
    -r /target \
    ${PACKAGES}

FROM scratch AS image
ARG IMAGETYPE
COPY --link --from=install /target /
COPY scripts/post-$IMAGETYPE.sh /post.sh
RUN \
  . /post.sh; \
  install -dm1777 tmp; \
  xbps-reconfigure -fa; \
  rm -rf /var/cache/xbps/*; \
  rm -f /post.sh
CMD ["/bin/sh"]
