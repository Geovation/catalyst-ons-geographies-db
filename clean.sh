#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"
dry_run=false

usage() {
	printf '%s\n' \
		'Usage: bash clean.sh [--dry-run]' \
		'  Remove all data/ contents except maintained files in data/source/.' \
		'  Remove *.duckdb databases and *.duckdb.wal files in the root and dist/.' \
		'  --dry-run  List paths without deleting them' \
		'  --help     Show this help'
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--dry-run) dry_run=true ;;
		--help|-h) usage; exit 0 ;;
		*) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 1 ;;
	esac
	shift
done

for directory in data dist; do
	if [[ -L "$directory" ]]; then
		printf 'Refusing to clean symlinked directory: %s\n' "$directory" >&2
		exit 1
	fi
done

remove_path() {
	if "$dry_run"; then
		printf 'Would remove: %s\n' "$1"
	else
		rm -rf -- "$1"
		printf 'Removed: %s\n' "$1"
	fi
}

if [[ -d data ]]; then
	while IFS= read -r -d '' path; do
		remove_path "$path"
	done < <(find data -mindepth 1 -maxdepth 1 ! -name source -print0)
fi

for directory in . dist; do
	if [[ -d "$directory" ]]; then
		while IFS= read -r -d '' path; do
			remove_path "$path"
		done < <(find "$directory" -mindepth 1 -maxdepth 1 \( -type f -o -type l \) \
			\( -name '*.duckdb' -o -name '*.duckdb.wal' \) -print0)
	fi
done