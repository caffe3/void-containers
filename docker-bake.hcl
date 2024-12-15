variable "MIRROR" {
  default = "https://repo-ci.voidlinux.org/"
}

variable "CACHEDIR" {
  default = "/tmp/buildx-cache"
}

variable "COMPRESSION" {
  default = "zstd"
}

function "tag" {
  params = []
  result = formatdate("YYYYMMDD'T'HHmmssZ", timestamp())
}

function "label" {
  params = [libc, base, flavor]
  result = "${libc}${replace("-${base.name}-${flavor.name}","-default","")}"
}

target "docker-metadata-action" {}

target "_common" {
  inherits = ["docker-metadata-action"]
  dockerfile = "Containerfile"
  no-cache-filter = ["pre-bootstrap"]
  cache-to = ["type=local,dest=${CACHEDIR},compression=zstd,compression-level=22"]
  cache-from = ["type=local,src=${CACHEDIR}"]
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

common_pkgs  = ["xbps", "base-files"]
default_pkgs = ["dash", "coreutils", "grep", "run-parts", "sed", "gawk", "tar", "gzip", "zstd"]
repo_pkgs    = ["git", "xdelta3", "curl"]
devel_pkgs   = ["base-devel", "libgomp-devel", "libnuma-devel", "openblas-devel", "gcc-fortran"]
term_pkgs    = ["st-terminfo", "ncurses-term", "nvi"]
ssh_pkgs     = ["openssh", "socklog", "socklog-void", "iproute2", "iputils", "bash"]
busybox_pkgs = ["busybox-huge"]
base_pkgs = {
  default = concat(common_pkgs, default_pkgs)
  busybox = concat(common_pkgs, busybox_pkgs)
  full    = ["base-container"]
}
flavor_pkgs = {
  default = [["xbps"]]
  repo = [repo_pkgs]
  devel = [repo_pkgs, devel_pkgs]
}
all_pkgs = sort(flatten(values(flavor_pkgs)))

target "void" {
  name = "void-${label(libc, base, flavor)}"
  inherits = ["_common-${libc}"]
  target = "image"
  matrix = {
    libc = ["glibc", "musl"]
    base = [
      {
        name = "default"
        pkgs = base_pkgs.default
      },
      {
        name = "busybox"
        pkgs = base_pkgs.busybox
      },
      {
        name = "full"
        pkgs = base_pkgs.full
      }
    ]
    flavor = [
      {
        name = "default"
        sets = flavor_pkgs.default
      },
      {
        name = "repo"
        sets = flavor_pkgs.repo
      },
      {
        name = "devel"
        sets = flavor_pkgs.devel
      }
    ]
  }
  args = {
    "BASE" = base.name
    "FLAVOR" = flavor.name
    "IMAGETYPE" = (base.name == flavor.name) ? "base" : "flavor"
    "BASEPKGS" = join(" ", base.pkgs)
    "SET0PKGS" = length(flavor.sets) >= 0 ? join(" ", sort(element(flavor.sets, 0))) : ""
    "SET1PKGS" = length(flavor.sets) >= 1 ? join(" ", sort(element(flavor.sets, 1))) : ""
    "SET2PKGS" = length(flavor.sets) >= 2 ? join(" ", sort(element(flavor.sets, 2))) : ""
    "SETPKGS" = join(" ", sort(flatten(flavor.sets)))
    "ALLPKGS" = join(" ", all_pkgs)
    "LASTSET" = length(flavor.sets) - 1
    "LIBC" = libc
  }
  tags = [
    "caffe3/void-${label(libc, base, flavor)}:${tag()}",
    "caffe3/void-${label(libc, base, flavor)}:latest"
  ]
}
