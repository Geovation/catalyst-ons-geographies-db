#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"
dataset=onspd
with_boundaries=false
onspd_url=https://www.arcgis.com/sharing/rest/content/items/9e5a92a3cfb14dc7ad43d6ea7a7b8c7f/data
nsul_url=https://www.arcgis.com/sharing/rest/content/items/03c840334eb3496a97574abe1f86af10/data
nsul_format=zip
lsoa_url=https://services1.arcgis.com/ESMARspQHYMw9BZ9/arcgis/rest/services/Lower_layer_Super_Output_Areas_December_2021_Boundaries_EW_BGC_V5/FeatureServer/replicafilescache/Lower_layer_Super_Output_Areas_December_2021_Boundaries_EW_BGC_V5_-7764840717091613250.geojson
msoa_url=https://services1.arcgis.com/ESMARspQHYMw9BZ9/arcgis/rest/services/Middle_layer_Super_Output_Areas_December_2021_Boundaries_EW_BGC_V3/FeatureServer/replicafilescache/Middle_layer_Super_Output_Areas_December_2021_Boundaries_EW_BGC_V3_4916445166053426.geojson
force=false

usage() {
	printf '%s\n' \
		'Usage: bash download.sh [options]' \
		'  --dataset onspd|nsul|all  Dataset to download (default: onspd)' \
		'  --with-boundaries           Also download LSOA/MSOA boundaries' \
		'  --onspd-url URL          Override the default August 2026 ONSPD ZIP URL' \
		'  --nsul-url URL               Override the default September 2026 NSUL ZIP URL' \
		'  --nsul-format csv|parquet|zip NSUL download format (default: zip)' \
		'  --lsoa-url URL               Override the 2021 EW LSOA GeoJSON URL' \
		'  --msoa-url URL               Override the 2021 EW MSOA GeoJSON URL' \
		'  --force                     Replace existing downloaded files' \
		'  --help                      Show this help'
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--dataset|--onspd-url|--nsul-url|--nsul-format|--lsoa-url|--msoa-url)
			if [[ $# -lt 2 || -z "$2" || "$2" == --* ]]; then
				printf 'Missing value for %s\n' "$1" >&2
				exit 1
			fi
			case "$1" in
				--dataset) dataset=$2 ;;
				--onspd-url) onspd_url=$2 ;;
				--nsul-url) nsul_url=$2 ;;
				--nsul-format) nsul_format=$2 ;;
				--lsoa-url) lsoa_url=$2 ;;
				--msoa-url) msoa_url=$2 ;;
			esac
			shift 2
			;;
		--with-boundaries) with_boundaries=true; shift ;;
		--force) force=true; shift ;;
		--help|-h) usage; exit 0 ;;
		*) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 1 ;;
	esac
done

case "$dataset" in
	onspd|nsul|all) ;;
	*) printf 'Invalid dataset: %s\n' "$dataset" >&2; exit 1 ;;
esac
case "$nsul_format" in
	csv|parquet|zip) ;;
	*) printf 'Invalid NSUL format: %s\n' "$nsul_format" >&2; exit 1 ;;
esac
urls=()
files=()
if [[ "$dataset" != nsul ]]; then
	urls+=("$onspd_url")
	files+=(onspd.zip)
fi
if [[ "$dataset" != onspd ]]; then
	urls+=("$nsul_url")
	files+=("nsul.$nsul_format")
fi
if "$with_boundaries"; then
	urls+=("$lsoa_url" "$msoa_url")
	files+=(lsoas.geojson msoas.geojson)
fi
for file in "${files[@]}"; do
	if [[ -e "data/downloads/$file" ]] && ! "$force"; then
		printf 'Download already exists: data/downloads/%s (use --force to replace it)\n' "$file" >&2
		exit 1
	fi
done

mkdir -p data/downloads
temporary_dir=$(mktemp -d data/download.XXXXXX)
trap 'rm -rf "$temporary_dir"' EXIT
for index in "${!files[@]}"; do
	file=${files[$index]}
	printf 'Downloading %s\n' "$file"
	curl --fail --location --retry 3 --output "$temporary_dir/$file" "${urls[$index]}"
done
for file in "${files[@]}"; do
	mv "$temporary_dir/$file" "data/downloads/$file"
	printf 'Downloaded data/downloads/%s\n' "$file"
done