variable "MIRROR" {
  default = "https://repo-ci.voidlinux.org/"
}

variable "TAG" {
  default = "latest"
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
    "PACKAGES" = "xbps base-files dash coreutils grep run-parts sed gawk"
  }
}

target "_common-busybox" {
  args = {
    "PACKAGES" = "xbps base-files busybox-huge"
  }
}

target "_common-full" {
  args = {
    "PACKAGES" = "base-container"
  }
}

target "void" {
  name = "void-${libc}${flavor=="default"?"":"-"}${replace(flavor, "default", "")}"
  inherits = ["_common-${libc}", "_common-${flavor}"]
  matrix = {
    libc = ["glibc", "musl"]
    flavor = ["default", "busybox", "full"]
  }
  args = {
    "FLAVOR" = "${flavor}"
  }
}
