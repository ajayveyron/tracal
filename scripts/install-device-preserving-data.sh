#!/bin/zsh

set -euo pipefail
umask 077

BUNDLE_ID="com.ajaypawriya.tracal"
DEFAULT_DEVICE="00008150-00155D222228401C"
APP_PATH="${1:-}"
DEVICE="${2:-$DEFAULT_DEVICE}"
BACKUP_ROOT="$HOME/Library/Application Support/TracalDeviceBackups"

if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  print -u2 "Usage: $0 /absolute/path/to/Tracal.app [device-id]"
  exit 64
fi

if pgrep -f '/DeviceHub.app/' >/dev/null 2>&1; then
  print -u2 "Device Hub is running. Quit it before installing Tracal."
  exit 65
fi

if [[ -z "${DEVELOPER_DIR:-}" ]]; then
  if [[ -d "$HOME/Downloads/Xcode-beta.app/Contents/Developer" ]]; then
    export DEVELOPER_DIR="$HOME/Downloads/Xcode-beta.app/Contents/Developer"
  elif [[ -d "/Applications/Xcode.app/Contents/Developer" ]]; then
    export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
  fi
fi

timestamp="$(date '+%Y%m%d-%H%M%S')"
backup="$BACKUP_ROOT/$timestamp"
before="$backup/before"
after="$backup/after"
mkdir -p "$before" "$after"

copy_from_device() {
  local source="$1"
  local destination="$2"
  xcrun devicectl device copy from \
    --device "$DEVICE" \
    --domain-type appDataContainer \
    --domain-identifier "$BUNDLE_ID" \
    --source "$source" \
    --destination "$destination"
}

snapshot() {
  local destination="$1"
  mkdir -p "$destination"
  copy_from_device "Library/Application Support" "$destination/ApplicationSupport"
  copy_from_device "Documents" "$destination/Documents"
  copy_from_device "Library/Preferences" "$destination/Preferences"
}

database_counts() {
  local database="$1/ApplicationSupport/default.store"
  if [[ ! -f "$database" ]]; then
    print "0|0|0"
    return
  fi
  sqlite3 "$database" \
    "SELECT (SELECT count(*) FROM ZDAILYGOAL) || '|' || (SELECT count(*) FROM ZMEALENTRY) || '|' || (SELECT count(*) FROM ZFOODITEM);"
}

file_sha256() {
  local file="$1"
  if [[ -f "$file" ]]; then
    shasum -a 256 "$file" | awk '{ print $1 }'
  else
    print "missing"
  fi
}

database_fingerprint() {
  local application_support="$1/ApplicationSupport"
  print "$(file_sha256 "$application_support/default.store")|$(file_sha256 "$application_support/default.store-wal")"
}

database_integrity() {
  local database="$1/ApplicationSupport/default.store"
  if [[ ! -f "$database" ]]; then
    print "missing"
    return
  fi
  sqlite3 "$database" "PRAGMA integrity_check;"
}

snapshot "$before"
before_counts="$(database_counts "$before")"
before_fingerprint="$(database_fingerprint "$before")"
before_integrity="$(database_integrity "$before")"
build_number="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_PATH/Info.plist")"

{
  print "created_at=$timestamp"
  print "device=$DEVICE"
  print "bundle_id=$BUNDLE_ID"
  print "build=$build_number"
  print "before_counts=$before_counts"
  print "before_database_sha256=$before_fingerprint"
  print "before_integrity=$before_integrity"
  print "app_path=$APP_PATH"
} > "$backup/manifest.txt"

print "Backed up Tracal data to: $backup"
print "Before install (goals|meals|items): $before_counts"

xcrun devicectl device install app --device "$DEVICE" "$APP_PATH"

snapshot "$after"
after_counts="$(database_counts "$after")"
after_fingerprint="$(database_fingerprint "$after")"
after_integrity="$(database_integrity "$after")"
{
  print "after_counts=$after_counts"
  print "after_database_sha256=$after_fingerprint"
  print "after_integrity=$after_integrity"
} >> "$backup/manifest.txt"
print "After install  (goals|meals|items): $after_counts"

if [[ "$before_integrity" != "ok" || "$after_integrity" != "ok" ]]; then
  print -u2 "Database integrity verification failed. The pre-install backup is safe at: $before"
  print -u2 "Do not launch Tracal until that backup has been inspected."
  exit 66
fi

if [[ "$before_counts" != "$after_counts" || "$before_fingerprint" != "$after_fingerprint" ]]; then
  print -u2 "Data verification failed. The pre-install backup is safe at: $before"
  print -u2 "Do not launch Tracal until that backup has been restored."
  exit 66
fi

print "Install verified: the SwiftData store, WAL, and record counts were preserved."
