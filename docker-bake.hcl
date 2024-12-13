variable "MIRROR" {
  default = "https://repo-ci.voidlinux.org/"
}

target "docker-metadata-action" {}

target "_common" {
  inherits = ["docker-metadata-action"]
  dockerfile = "Containerfile"
  no-cache-filter = ["bootstrap"]
  cache-to = ["type=local,dest=/tmp/buildx-cache"]
  cache-from = ["type=local,src=/tmp/buildx-cache"]
  args = {
    "MIRROR" = "${MIRROR}"
  }
}

target "_common-glibc" {
  inherits = ["_common"]
  platforms = ["linux/amd64", "linux/386", "linux/arm64", "linux/arm/v7", "linux/arm/v6"]
  args = { "LIBC" = "glibc" }
}

target "_common-musl" {
  inherits = ["_common"]
  platforms = ["linux/amd64", "linux/arm64", "linux/arm/v7", "linux/arm/v6"]
  args = { "LIBC" = "musl" }
}

target "_common-default" {
  args = {
    "IMAGETYPE" = "default"
    "PACKAGES" = "xbps base-files dash coreutils grep run-parts sed gawk"
  }
}

target "_common-busybox" {
  args = {
    "IMAGETYPE" = "default"
    "PACKAGES" = "xbps base-files busybox-huge"
  }
}

target "_common-full" {
  args = {
    "IMAGETYPE" = "default"
    "PACKAGES" = "base-container"
  }
}

target "void-glibc" {
  inherits = ["_common-glibc", "_common-default"]
  target = "image"
}

target "void-glibc-busybox" {
  inherits = ["_common-glibc", "_common-busybox"]
  target = "image"
}

target "void-glibc-full" {
  inherits = ["_common-glibc", "_common-full"]
  target = "image"
}

target "void-musl" {
  inherits = ["_common-musl", "_common-default"]
  target = "image"
}

target "void-musl-busybox" {
  inherits = ["_common-musl", "_common-busybox"]
  target = "image"
}

target "void-musl-full" {
  inherits = ["_common-musl", "_common-full"]
  target = "image"
}
