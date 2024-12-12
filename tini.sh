#!/bin/sh

sh /etc/runit/core-services/06-ssh-root.sh
sh /etc/runit/core-services/06-ssh-void.sh
[ -x /etc/rc.local ] && /etc/rc.local

runsvchdir default
mkdir -p /run/runit/runsvdir
ln -s /etc/runit/runsvdir/current /run/runit/runsvdir/current

PATH=/usr/bin:/usr/sbin

exec env - PATH=$PATH \
    runsvdir -P /run/runit/runsvdir/current 'log: ...........................................................................................................................................................................................................................................................................................................................................................................................................'
