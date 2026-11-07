#!/bin/sh
# Daily pg_dump with local rotation and an optional off-server copy (rclone).
# `backup.sh now` makes one dump and exits; without arguments it loops forever.
set -eu

BACKUP_HOUR="${BACKUP_HOUR:-3}"
BACKUP_KEEP_DAYS="${BACKUP_KEEP_DAYS:-14}"
RCLONE_REMOTE="${RCLONE_REMOTE:-}"
DIR=/backups

dump() {
	stamp=$(date -u +%Y%m%d-%H%M%S)
	file="$DIR/peliculas-$stamp.dump"
	echo "backup: dumping to $file"
	pg_dump --format=custom --compress=9 --file="$file.tmp"
	# A dump that pg_restore cannot read is worse than none.
	pg_restore --list "$file.tmp" >/dev/null
	mv "$file.tmp" "$file"
	echo "backup: ok ($(du -h "$file" | cut -f1))"

	find "$DIR" -name 'peliculas-*.dump' -mtime +"$BACKUP_KEEP_DAYS" -print -delete

	if [ -n "$RCLONE_REMOTE" ]; then
		rclone copy "$file" "$RCLONE_REMOTE" && echo "backup: copied to $RCLONE_REMOTE"
		rclone delete "$RCLONE_REMOTE" --min-age "${BACKUP_KEEP_DAYS}d" --include 'peliculas-*.dump' || true
	fi
}

mkdir -p "$DIR"
if [ "${1:-}" = "now" ]; then
	dump
	exit 0
fi

echo "backup: daily at ${BACKUP_HOUR}:00 UTC, keeping ${BACKUP_KEEP_DAYS} days"
while true; do
	now=$(date -u +%s)
	next=$(( now - now % 86400 + BACKUP_HOUR * 3600 ))
	[ "$next" -le "$now" ] && next=$(( next + 86400 ))
	sleep $(( next - now ))
	dump || echo "backup: FAILED" >&2
done
