#!/bin/sh

if test $# -lt 3; then
        TMPFILE=$(mktemp)
        trap "rm -f '${TMPFILE}'" EXIT INT
else
        TMPFILE=$3
fi

deps() {
  apt-cache show "$1" | \
    grep -E "Depends|Recommends|Suggests|Pre-Depends" | \
    tr -d "|," | sed "s/([^)]*)/()/g" | tr -d "()" | tr " " "\n" | \
    grep -Ev "Depends|Recommends|Suggests|Pre-Depends" | \
    grep . | tee -a "${TMPFILE}"
}

if test $1 -eq 0; then
        echo $2
        deps "$2"
        exit 0
fi

DEPTHDEP="deps "$2" $(seq "${1:-1}" | awk "{printf(\" | xargs -I{} apt-dep.sh %d {} $TMPFILE\", 0)}")"
eval $DEPTHDEP | awk '!visited[$0]++'
