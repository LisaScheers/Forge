# Thumbnails are reproducible from originals and their retained database rows.
# Delete only their generated checkpoint copies before copying new originals.
options=(-a --delete-before --delete-excluded
  --exclude=/local_thumbnails/
  --exclude=/remote_thumbnail/
  --exclude=/url_cache_thumbnails/)
if [[ -n "${MEDIA_RSYNC_SSH:-}" ]]; then
  options+=(-e "$MEDIA_RSYNC_SSH")
fi
rsync "${options[@]}" "$1/" "$2/"
