#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"
dataset=onspd
with_boundaries=false
onspd_file=data/prepared/onspd.parquet
nsul_file=data/prepared/nsul.parquet
onspd_lookups_dir=data/lookups/onspd
nsul_lookups_dir=data/lookups/nsul
output=

usage() {
	printf '%s\n' \
		'Usage: bash createdb.sh [options]' \
		'  --dataset onspd|nsul|all  Dataset to include (default: onspd)' \
		'  --with-boundaries           Include LSOA and MSOA boundaries' \
		'  --onspd-file PATH       ONSPD CSV or Parquet input (default: data/prepared/onspd.parquet)' \
		'  --nsul-file PATH            NSUL CSV or Parquet (default: data/prepared/nsul.parquet)' \
		'  --onspd-lookups-dir PATH    ONSPD geography CSV/Parquet folder (default: data/lookups/onspd)' \
		'  --nsul-lookups-dir PATH     NSUL geography CSV/Parquet folder (default: data/lookups/nsul)' \
		'  --output PATH               Override ons-<dataset>[-boundaries].duckdb' \
		'  --help                      Show this help'
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--dataset|--onspd-file|--nsul-file|--onspd-lookups-dir|--nsul-lookups-dir|--output)
			if [[ $# -lt 2 || -z "$2" || "$2" == --* ]]; then
				printf 'Missing value for %s\n' "$1" >&2
				exit 1
			fi
			case "$1" in
				--dataset) dataset=$2 ;;
				--onspd-file) onspd_file=$2 ;;
				--nsul-file) nsul_file=$2 ;;
				--onspd-lookups-dir) onspd_lookups_dir=$2 ;;
				--nsul-lookups-dir) nsul_lookups_dir=$2 ;;
				--output) output=$2 ;;
			esac
			shift 2
			;;
		--with-boundaries) with_boundaries=true; shift ;;
		--help|-h) usage; exit 0 ;;
		*) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 1 ;;
	esac
done

case "$dataset" in
	onspd|nsul|all) ;;
	*) printf 'Invalid dataset: %s\n' "$dataset" >&2; exit 1 ;;
esac

if [[ -z "$output" ]]; then
	output=ons-$dataset
	if "$with_boundaries"; then output+=-boundaries; fi
	output+=.duckdb
fi

shared_tables=(built_up_area country county county_electoral_division
	local_authority_district region westminster_parliamentary_constituency ward)
nsul_tables=(health_area european_electoral_region travel_to_work_area
	international_territorial_level national_park lower_super_output_area_21
	middle_super_output_area_21 sub_integrated_care_board rural_urban_21_indicator
	output_area_classification_21 local_enterprise_partnership police_force_area)
for source in onspd nsul; do
	if [[ "$dataset" != all && "$dataset" != "$source" ]]; then continue; fi
	if [[ "$source" == onspd ]]; then
		lookup_dir=$onspd_lookups_dir
		lookup_tables=("${shared_tables[@]}" rural_urban_11_indicator)
	else
		lookup_dir=$nsul_lookups_dir
		lookup_tables=("${shared_tables[@]}" "${nsul_tables[@]}")
	fi
	for table in "${lookup_tables[@]}"; do
		if [[ ! -f "$lookup_dir/$table.parquet" ]]; then
			printf '%s name lookup not found: %s/%s.parquet (run process.sh first)\n' "$source" "$lookup_dir" "$table" >&2
			exit 1
		fi
	done
done

if [[ -e "$output" ]]; then
	printf 'Output already exists: %s (choose another --output or remove it first)\n' "$output" >&2
	exit 1
fi
if [[ "$dataset" != onspd && ! -f "$nsul_file" ]]; then
	printf 'NSUL input not found: %s\n' "$nsul_file" >&2
	exit 1
fi
if [[ "$dataset" != nsul && ! -f "$onspd_file" ]]; then
	printf 'ONSPD input not found: %s\n' "$onspd_file" >&2
	exit 1
fi
if [[ "$dataset" != nsul ]]; then
	case "$onspd_file" in
		*.csv|*.CSV) onspd_reader="read_csv(getenv('ONSPD_FILE'), header = true, all_varchar = true, normalize_names = true)" ;;
		*.parquet) onspd_reader="read_parquet(getenv('ONSPD_FILE'))" ;;
		*) printf 'ONSPD input must be CSV or Parquet: %s\n' "$onspd_file" >&2; exit 1 ;;
	esac
fi
if [[ "$dataset" != onspd ]]; then
	case "$nsul_file" in
		*.csv|*.CSV) nsul_reader="read_csv(getenv('NSUL_FILE'), header = true, all_varchar = true, normalize_names = true)" ;;
		*.parquet) nsul_reader="read_parquet(getenv('NSUL_FILE'))" ;;
		*) printf 'NSUL input must be CSV or Parquet: %s\n' "$nsul_file" >&2; exit 1 ;;
	esac
fi
if "$with_boundaries"; then
	for boundary in data/prepared/lsoas.parquet data/prepared/msoas.parquet; do
		if [[ ! -f "$boundary" ]]; then
			printf 'Boundary input not found: %s (run download.sh and process.sh)\n' "$boundary" >&2
			exit 1
		fi
	done
fi

temporary_dir=$(mktemp -d "${output}.build.XXXXXX")
trap 'rm -rf "$temporary_dir"' EXIT
database=$temporary_dir/database.duckdb
sql_database=${database//\'/\'\'}
commands=(-c "ATTACH '$sql_database' AS build (STORAGE_VERSION 'v1.5.0'); USE build;")
if [[ "$dataset" != nsul ]] || "$with_boundaries"; then
	commands+=(-c 'INSTALL spatial; LOAD spatial;')
fi
for table in "${shared_tables[@]}"; do
	commands+=(-c ".read schema/tbl_$table.sql")
done
if [[ "$dataset" != nsul ]]; then
	commands+=(-c '.read schema/tbl_rural_urban_11_indicator.sql'
		-c '.read load_onspd_lookups.sql'
		-c '.read schema/tbl_postcodes.sql'
		-c "CREATE TEMP VIEW onspd_source AS SELECT
			pcds, doterm, cty25cd, ced25cd, lad25cd, wd25cd, east1m, north1m,
			ctry25cd, rgn25cd, pcon24cd, oa11cd, lsoa11cd, msoa11cd,
			bua24cd, ruc11ind, imd20ind, oa21cd, lsoa21cd, msoa21cd, lat, long
			FROM $onspd_reader;"
		-c '.read load_postcodes.sql'
		-c '.read schema/tbl_postcodes_indexes.sql'
		-c '.read schema/vw_postcodes.sql')
fi
if [[ "$dataset" != onspd ]]; then
	for table in "${nsul_tables[@]}"; do
		commands+=(-c ".read schema/tbl_$table.sql")
	done
	commands+=(-c '.read load_nsul_lookups.sql'
		-c '.read schema/tbl_uprns.sql'
		-c "CREATE TEMP VIEW nsul_source AS SELECT
			uprn, gridgb1e, gridgb1n, pcds, oa21cd, cty26cd, ced25cd, lad26cd,
			wd26cd, hlth19cd, ctry26cd, rgn26cd, pcon24cd, eer20cd, ttwa15cd,
			itl25cd, npark16cd, lsoa21cd, msoa21cd, wz11cd, sicbl26cd, bua24cd,
			buasd11cd, ruc21ind, oac21ind, lep21cd1, lep21cd2, pfa23cd, imd25ind
			FROM $nsul_reader;"
		-c '.read load_uprns.sql'
		-c '.read schema/vw_uprns.sql')
fi
if "$with_boundaries"; then
	commands+=(-c '.read schema/tbl_lower_super_output_area.sql'
		-c '.read schema/tbl_middle_super_output_area.sql'
		-c '.read load_boundaries.sql'
		-c '.read schema/tbl_lower_super_output_area_indexes.sql'
		-c '.read schema/tbl_middle_super_output_area_indexes.sql')
fi
NSUL_FILE="$nsul_file" NSUL_LOOKUPS_DIR="$nsul_lookups_dir" ONSPD_FILE="$onspd_file" ONSPD_LOOKUPS_DIR="$onspd_lookups_dir" duckdb -bail "${commands[@]}"

mv "$database" "$output"
printf 'Created %s\n' "$output"