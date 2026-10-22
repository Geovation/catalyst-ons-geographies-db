#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"
dataset=onspd
with_boundaries=false
onspd_file=data/downloads/onspd.zip
nsul_file=data/downloads/nsul.zip
nsul_member=

usage() {
	printf '%s\n' \
		'Usage: bash process.sh [options]' \
		'  --dataset onspd|nsul|all  Dataset to prepare (default: onspd)' \
		'  --with-boundaries           Also prepare LSOA/MSOA boundaries' \
		'  --onspd-file PATH       ONSPD ZIP (default: data/downloads/onspd.zip)' \
		'  --nsul-file PATH            NSUL ZIP, CSV or Parquet (default: data/downloads/nsul.zip)' \
		'  --nsul-member PATH          Extract one CSV; otherwise combine regional NSUL CSVs' \
		'  --help                      Show this help'
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--dataset|--onspd-file|--nsul-file|--nsul-member)
			if [[ $# -lt 2 || -z "$2" || "$2" == --* ]]; then
				printf 'Missing value for %s\n' "$1" >&2
				exit 1
			fi
			case "$1" in
				--dataset) dataset=$2 ;;
				--onspd-file) onspd_file=$2 ;;
				--nsul-file) nsul_file=$2 ;;
				--nsul-member) nsul_member=$2 ;;
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
if [[ "$dataset" != nsul && ! -f "$onspd_file" ]]; then
	printf 'ONSPD ZIP not found: %s (run download.sh first)\n' "$onspd_file" >&2
	exit 1
fi
if [[ "$dataset" != onspd ]]; then
	if [[ ! -f "$nsul_file" ]]; then
		printf 'NSUL input not found: %s\n' "$nsul_file" >&2
		exit 1
	fi
	case "$nsul_file" in
		*.zip|*.csv|*.CSV|*.parquet) ;;
		*) printf 'NSUL input must be ZIP, CSV or Parquet: %s\n' "$nsul_file" >&2; exit 1 ;;
	esac
fi
if "$with_boundaries"; then
	for boundary in data/downloads/lsoas.geojson data/downloads/msoas.geojson; do
		if [[ ! -f "$boundary" ]]; then
			printf 'Boundary input not found: %s (download with --with-boundaries)\n' "$boundary" >&2
			exit 1
		fi
	done
fi

mkdir -p data/prepared data/lookups
temporary_dir=$(mktemp -d data/process.XXXXXX)
trap 'rm -rf "$temporary_dir"' EXIT
mkdir "$temporary_dir/output"
export PROCESS_DIR="$temporary_dir"

extract_csv_parts() {
	local archive=$1 pattern=$2 destination=$3
	local archive_member member_count=0
	mkdir "$destination"
	unzip -Z1 "$archive" > "$destination/members.txt"
	while IFS= read -r archive_member; do
		if [[ "$archive_member" == $pattern ]]; then
			member_count=$((member_count + 1))
			unzip -p "$archive" "$archive_member" > "$destination/part_$member_count.csv"
		fi
	done < "$destination/members.txt"
	if [[ "$member_count" -eq 0 ]]; then
		printf 'No CSV files matching %s in %s\n' "$pattern" "$archive" >&2
		exit 1
	fi
}

export_lookup() {
	local source_query=$1 destination=$2 columns=${3:-code, name}
	LOOKUP_DESTINATION="$destination" duckdb -bail -c "
		CREATE TEMP TABLE prepared_lookup AS $source_query;
		COPY (SELECT $columns FROM prepared_lookup)
			TO (getenv('LOOKUP_DESTINATION') || '.csv') (HEADER);
		COPY (SELECT $columns FROM prepared_lookup)
			TO (getenv('LOOKUP_DESTINATION') || '.parquet');"
}

if [[ "$dataset" != nsul ]]; then
	printf 'Preparing ONSPD: %s\n' "$onspd_file"
	onspd_members=$(unzip -Z1 "$onspd_file")
	onspd_pattern='Data/ONSPD_*.csv'
	if [[ "$onspd_members" == *"Data/multi_csv/ONSPD_"* ]]; then
		onspd_pattern='Data/multi_csv/ONSPD_*.csv'
	fi
	extract_csv_parts "$onspd_file" "$onspd_pattern" "$temporary_dir/onspd"
	duckdb -bail <<'SQL'
COPY (
	SELECT pcds, doterm, cty26cd AS cty25cd, ced25cd,
		lad26cd AS lad25cd, wd26cd AS wd25cd, east1m, north1m,
		ctry26cd AS ctry25cd, rgn26cd AS rgn25cd, pcon24cd,
		oa11cd, lsoa11cd, msoa11cd, bua24cd, ruc11ind,
		imd25ind AS imd20ind, oa21cd, lsoa21cd, msoa21cd, lat, long
	FROM read_csv(getenv('PROCESS_DIR') || '/onspd/part_*.csv',
		header = true, all_varchar = true, union_by_name = true)
) TO (getenv('PROCESS_DIR') || '/output/onspd.parquet');
SQL
	mkdir "$temporary_dir/output/onspd-lookups"
	while IFS='|' read -r table member code name; do
		unzip -p "$onspd_file" "Documents/$member*.csv" > "$temporary_dir/$table.csv"
		export_lookup "SELECT $code AS code, min($name) AS name
			FROM read_csv(getenv('PROCESS_DIR') || '/$table.csv', header = true, all_varchar = true)
			WHERE $code IS NOT NULL GROUP BY $code" "$temporary_dir/output/onspd-lookups/$table"
	done <<'LOOKUPS'
built_up_area|BUA Built Up Area names and codes|BUA24CD|BUA24NM
country|CTRY Country names and codes |CTRY25CD|CTRY25NM
county|CTY County names and codes|CTY25CD|CTY25NM
county_electoral_division|CED County Electoral Division names and codes|CED25CD|CED25NM
local_authority_district|LAD Local Authority District names and codes|LAD25CD|LAD25NM
region|RGN Region names and codes |RGN25CD|RGN25NM
rural_urban_11_indicator|RUC11 Rural Urban (2011) Indicator names and codes|RU11IND|RU11NM
ward|WD Ward names and codes|WD26CD|WD26NM
westminster_parliamentary_constituency|PCON Westminster Parliamentary Constituency names and codes|PCON24CD|PCON24NM
LOOKUPS
fi

if [[ "$dataset" != onspd ]]; then
	printf 'Preparing NSUL: %s\n' "$nsul_file"
	case "$nsul_file" in
		*.zip)
			nsul_pattern=${nsul_member:-'*[Nn][Ss][Uu][Ll]_*.[Cc][Ss][Vv]'}
			extract_csv_parts "$nsul_file" "$nsul_pattern" "$temporary_dir/nsul"
			mkdir "$temporary_dir/nsul-lookups"
			while IFS='|' read -r lookup geography member code name; do
				extract_csv_parts "$nsul_file" "Documents/$member*.csv" "$temporary_dir/lookup-$lookup"
				LOOKUP_ID="$lookup" LOOKUP_GEOGRAPHY="$geography" duckdb -bail -c "COPY (
					SELECT DISTINCT getenv('LOOKUP_GEOGRAPHY') AS geography,
						upper(CAST($code AS VARCHAR)) AS code, CAST($name AS VARCHAR) AS name
					FROM read_csv(getenv('PROCESS_DIR') || '/lookup-' || getenv('LOOKUP_ID') || '/part_*.csv',
						header = true, all_varchar = true, union_by_name = true, null_padding = true)
					WHERE $code IS NOT NULL AND $name IS NOT NULL
				) TO (getenv('PROCESS_DIR') || '/nsul-lookups/' || getenv('LOOKUP_ID') || '.csv') (HEADER);"
			done <<'LOOKUPS'
country|country|CTRY*|CTRY25CD|CTRY25NM
county|county|CTY*|CTY25CD|CTY25NM
ced|county_electoral_division|CED*|CED25CD|CED25NM
lad|local_authority_district|LAD*|LAD25CD|LAD25NM
ward|ward|WD Ward*|WD26CD|WD26NM
region|region|RGN*|RGN25CD|RGN25NM
pcon|westminster_parliamentary_constituency|PCON*|PCON24CD|PCON24NM
bua|built_up_area_24|BUA*|BUA24CD|BUA24NM
health|health_area|HLTH*|HLTHAUCD|HLTHAUNM
eer|european_electoral_region|EER*|EER10CD|EER10NM
ttwa|travel_to_work_area|TTWA*|TTWA11CD|TTWA11NM
itl|international_territorial_level|ITL125_*|LAU125CD|LAU125NM
npark|national_park|NPARK*|NPARK16CD|NPARK16NM
lsoa|lower_super_output_area_21|LSOA21*EW*|LSOA21CD|LSOA21NM
dz|lower_super_output_area_21|LSOA21*SC*|DZ22CD|DZ22NM
msoa|middle_super_output_area_21|MSOA21*EW*|MSOA21CD|MSOA21NM
iz|middle_super_output_area_21|MSOA21*SC*|IZ22CD|IZ22NM
sicbl|sub_integrated_care_board|SICBL*|SICBL26CD|SICBL26NM
ruc|rural_urban_21|RUC21*|RUC21IND|RUC21DESC
oac|output_area_classification_21|OAC21*|OAC21IND|Subgroup
oac-group|output_area_classification_21_group|OAC21*|OAC21IND|"Group"
oac-supergroup|output_area_classification_21_supergroup|OAC21*|OAC21IND|Supergroup
lep|local_enterprise_partnership|LEP*|LEP21CD|LEP21NM
pfa|police_force_area|PFA*|PFA23CD|PFA23NM
LOOKUPS
			duckdb -bail <<'SQL'
COPY (
	SELECT geography, code,
		CASE WHEN count(DISTINCT name) = 1 THEN min(name)
			ELSE error('Conflicting NSUL lookup names for ' || geography || ': ' || code)
		END AS name
	FROM (
		SELECT geography, code, name
		FROM read_csv(getenv('PROCESS_DIR') || '/nsul-lookups/*.csv', header = true, all_varchar = true)
		UNION ALL
		SELECT supplement.geography, supplement.code, supplement.name
		FROM read_csv('data/source/nsul-geography-supplements.csv', header = true, delim = ',', all_varchar = true) supplement
		WHERE NOT EXISTS (
			SELECT 1 FROM read_csv(getenv('PROCESS_DIR') || '/nsul-lookups/*.csv', header = true, all_varchar = true) supplied
			WHERE supplied.geography = supplement.geography AND supplied.code = supplement.code
		)
	)
	GROUP BY geography, code
) TO (getenv('PROCESS_DIR') || '/nsul-lookups/validated.parquet');
SQL
			mkdir "$temporary_dir/output/nsul-lookups"
			while IFS='|' read -r table geography; do
				export_lookup "SELECT code, name
					FROM read_parquet(getenv('PROCESS_DIR') || '/nsul-lookups/validated.parquet')
					WHERE geography = '$geography'" "$temporary_dir/output/nsul-lookups/$table"
			done <<'LOOKUPS'
built_up_area|built_up_area_24
country|country
county|county
county_electoral_division|county_electoral_division
local_authority_district|local_authority_district
region|region
ward|ward
westminster_parliamentary_constituency|westminster_parliamentary_constituency
health_area|health_area
european_electoral_region|european_electoral_region
travel_to_work_area|travel_to_work_area
international_territorial_level|international_territorial_level
national_park|national_park
lower_super_output_area_21|lower_super_output_area_21
middle_super_output_area_21|middle_super_output_area_21
sub_integrated_care_board|sub_integrated_care_board
rural_urban_21_indicator|rural_urban_21
local_enterprise_partnership|local_enterprise_partnership
police_force_area|police_force_area
LOOKUPS
			export_lookup "SELECT subgroup.code, subgroup.name,
				parent_group.name AS group_name, supergroup.name AS supergroup_name
				FROM read_parquet(getenv('PROCESS_DIR') || '/nsul-lookups/validated.parquet') subgroup
				LEFT JOIN read_parquet(getenv('PROCESS_DIR') || '/nsul-lookups/validated.parquet') parent_group
					ON parent_group.geography = 'output_area_classification_21_group' AND parent_group.code = subgroup.code
				LEFT JOIN read_parquet(getenv('PROCESS_DIR') || '/nsul-lookups/validated.parquet') supergroup
					ON supergroup.geography = 'output_area_classification_21_supergroup' AND supergroup.code = subgroup.code
				WHERE subgroup.geography = 'output_area_classification_21'" \
				"$temporary_dir/output/nsul-lookups/output_area_classification_21" "code, name, group_name, supergroup_name"
			nsul_file="$temporary_dir/nsul/part_*.csv"
			;;
		*)
			for table in built_up_area country county county_electoral_division \
				local_authority_district region ward westminster_parliamentary_constituency \
				health_area european_electoral_region travel_to_work_area international_territorial_level \
				national_park lower_super_output_area_21 middle_super_output_area_21 sub_integrated_care_board \
				rural_urban_21_indicator output_area_classification_21 local_enterprise_partnership police_force_area; do
				if [[ ! -f "data/lookups/nsul/$table.parquet" ]]; then
					printf 'NSUL name lookup not found: data/lookups/nsul/%s.parquet (process the NSUL ZIP first)\n' "$table" >&2
					exit 1
				fi
			done
			;;
	esac
	case "$nsul_file" in
		*.parquet) cp "$nsul_file" "$temporary_dir/output/nsul.parquet" ;;
		*)
			NSUL_SOURCE="$nsul_file" duckdb -bail <<'SQL'
COPY (
	SELECT uprn, gridgb1e, gridgb1n, pcds, oa21cd, cty26cd, ced25cd, lad26cd,
		wd26cd, hlth19cd, ctry26cd, rgn26cd, pcon24cd, eer20cd, ttwa15cd,
		itl25cd, npark16cd, lsoa21cd, msoa21cd, wz11cd, sicbl26cd, bua24cd,
		buasd11cd, ruc21ind, oac21ind, lep21cd1, lep21cd2, pfa23cd, imd25ind
	FROM read_csv(getenv('NSUL_SOURCE'), header = true, all_varchar = true,
		union_by_name = true, normalize_names = true)
) TO (getenv('PROCESS_DIR') || '/output/nsul.parquet');
SQL
			;;
	esac
fi

if "$with_boundaries"; then
	for area in lsoa msoa; do
		printf 'Preparing %s boundaries\n' "$area"
		ogr2ogr -f GeoJSON -select "${area}21cd" "$temporary_dir/$area.geojson" "data/downloads/${area}s.geojson"
		gpq convert "$temporary_dir/$area.geojson" "$temporary_dir/output/${area}s.parquet"
	done
fi

for prepared_file in "$temporary_dir/output/"*; do
	if [[ -d "$prepared_file" ]]; then
		lookup_source=${prepared_file##*/}
		destination=data/lookups/${lookup_source%-lookups}
		mkdir -p "$destination"
		mv "$prepared_file/"* "$destination/"
	else
		mv "$prepared_file" data/prepared/
	fi
done
printf 'Prepared data for %s\n' "$dataset"