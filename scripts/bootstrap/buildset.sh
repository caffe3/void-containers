#!/bin/sh

OLD="$1"
NEW="$2"
UPD="$3"

find "$NEW" -type d \( -path "$NEW/var/db/xbps" -o -path "$NEW/var/cache/xbps" \) -prune -o -type f -print | while read -r f; do
  rel_path=$(echo "$f" | sed "s|^$NEW/||")
  if [ ! -f "$OLD/$rel_path" ] || ! cmp -s "$f" "$OLD/$rel_path"; then
    rel_dir=$(dirname "$rel_path")
    if ! test -d "$UPD/$rel_dir"; then
      dir=$(dirname "$f")
      install -d "$dir" "$UPD/$rel_dir" || exit 101
    fi
    install "$f" "$UPD/$rel_path" || exit 100
  fi
done
