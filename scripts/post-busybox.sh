#!/bin/sh

for util in $(/usr/bin/busybox --list); do \
  [ ! -f "/usr/bin/$util" ] && /usr/bin/busybox ln -sfv busybox "/usr/bin/$util"; \
done; \
