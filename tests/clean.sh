#!/bin/bash
set -euo pipefail

repository=$(cd "$(dirname "$0")/.." && pwd)
workspace=$(mktemp -d)
trap 'rm -rf "$workspace"' EXIT
cp "$repository/clean.sh" "$workspace/"
mkdir -p "$workspace/data/lookups/nsul" "$workspace/data/downloads" \
	"$workspace/data/source" "$workspace/dist/logs" "$workspace/outside"
printf 'source\n' > "$workspace/data/source/nsul-geography-supplements.csv"
touch "$workspace/data/downloads/onspd.zip" "$workspace/data/.hidden" \
	"$workspace/data/lookups/nsul/country.csv" "$workspace/data/lookups/nsul/country.parquet" \
	"$workspace/ons-all.duckdb" "$workspace/ons-all.duckdb.wal" \
	"$workspace/dist/custom database.duckdb" "$workspace/dist/custom database.duckdb.wal" \
	"$workspace/dist/logs/build.log" "$workspace/outside/keep.csv" "$workspace/README.md"
ln -s "$workspace/outside" "$workspace/data/external"
cd "$workspace/outside"
bash "$workspace/clean.sh" --dry-run
[[ -f "$workspace/data/downloads/onspd.zip" && -f "$workspace/dist/custom database.duckdb" ]]
if bash "$workspace/clean.sh" --invalid; then
	printf 'Expected invalid option to fail\n' >&2
	exit 1
fi
[[ -f "$workspace/data/downloads/onspd.zip" ]]
bash "$workspace/clean.sh"
[[ $(find "$workspace/data" -mindepth 1 | wc -l) -eq 2 ]]
[[ $(< "$workspace/data/source/nsul-geography-supplements.csv") == source ]]
[[ ! -e "$workspace/ons-all.duckdb" && ! -e "$workspace/ons-all.duckdb.wal" ]]
[[ ! -e "$workspace/dist/custom database.duckdb" && ! -e "$workspace/dist/custom database.duckdb.wal" ]]
[[ -f "$workspace/dist/logs/build.log" && -f keep.csv && -f "$workspace/README.md" ]]
bash "$workspace/clean.sh"
rm "$workspace/data/source/nsul-geography-supplements.csv"
rmdir "$workspace/data/source"
rmdir "$workspace/data"
ln -s "$workspace/outside" "$workspace/data"
if bash "$workspace/clean.sh"; then
	printf 'Expected symlinked data directory to fail\n' >&2
	exit 1
fi
[[ -f keep.csv ]]
rm "$workspace/data"
bash "$workspace/clean.sh"
printf 'All cleanup tests passed.\n'