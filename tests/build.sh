#!/bin/bash
set -euo pipefail

repository=$(cd "$(dirname "$0")/.." && pwd)
workspace=$(mktemp -d)
trap 'rm -rf "$workspace"' EXIT
cp "$repository/createdb.sh" "$repository"/load_*.sql "$workspace/"
cp -R "$repository/schema" "$workspace/"
mkdir -p "$workspace/data/lookups/onspd" "$workspace/data/lookups/nsul" \
    "$workspace/data/prepared" "$workspace/data/downloads"
cd "$workspace"

for schema_file in schema/*.sql; do
    schema_name=${schema_file##*/}
    schema_name=${schema_name%.sql}
    definition=$(head -n 1 "$schema_file")
    case "$schema_name" in
        vw_*)
            [[ "$definition" == "CREATE VIEW $schema_name AS" ]]
            [[ $(grep -c '^CREATE ' "$schema_file") -eq 1 ]]
            ;;
        tbl_*_indexes)
            table=${schema_name#tbl_}
            table=${table%_indexes}
            grep -q '^CREATE INDEX ' "$schema_file"
            while IFS= read -r definition || [[ -n "$definition" ]]; do
                [[ -z "$definition" || "$definition" == "CREATE INDEX "*" ON $table USING "* ]]
            done < "$schema_file"
            ;;
        tbl_*)
            [[ "$definition" == "CREATE TABLE ${schema_name#tbl_} (" ]]
            [[ $(grep -c '^CREATE ' "$schema_file") -eq 1 ]]
            ;;
        *) printf 'Unexpected schema filename: %s\n' "$schema_file" >&2; exit 1 ;;
    esac
done

duckdb -bail <<'SQL'
LOAD spatial;
COPY (WITH postcode_fixture AS (SELECT 'BA15 1DS' AS pcds, NULL::VARCHAR AS doterm,
    'E99999999' AS cty25cd, 'E99999999' AS ced25cd,
    'E06000054' AS lad25cd, 'E05013407' AS wd25cd,
    382678 AS east1m, 160818 AS north1m, 'E92000001' AS ctry25cd,
    'E12000009' AS rgn25cd, 'E14001356' AS pcon24cd,
    'E00163467' AS oa11cd, 'E01032050' AS lsoa11cd,
    'E02006682' AS msoa11cd, 'E63012462' AS bua24cd,
    'D1' AS ruc11ind, 27325 AS imd20ind, 'E00163467' AS oa21cd,
    'E01034532' AS lsoa21cd, 'E02006682' AS msoa21cd,
    51.346176 AS lat, -2.250094 AS long)
    SELECT pcds, doterm, cty25cd, ced25cd,
        lad25cd, wd25cd, east1m, north1m,
        ctry25cd, rgn25cd, pcon24cd, oa11cd,
        lsoa11cd, msoa11cd, bua24cd, ruc11ind,
        imd20ind, oa21cd, lsoa21cd, msoa21cd,
        lat, long FROM postcode_fixture
    UNION ALL
    SELECT 'BA15 2DS' AS pcds, doterm, 'ZZ-COUNTY' AS cty25cd, 'ZZ-CED' AS ced25cd,
        'ZZ-LAD' AS lad25cd, 'ZZ-WARD' AS wd25cd, east1m, north1m,
        'ZZ-COUNTRY' AS ctry25cd, 'ZZ-REGION' AS rgn25cd, 'ZZ-PCON' AS pcon24cd, oa11cd,
        lsoa11cd, msoa11cd, 'ZZ-BUA' AS bua24cd, 'ZZ-RUC' AS ruc11ind,
        imd20ind, oa21cd, lsoa21cd, msoa21cd,
        lat, long
    FROM postcode_fixture)
TO 'data/prepared/onspd.parquet';
COPY (SELECT 'E63012462' AS code, 'Bradford-on-Avon' AS name) TO 'data/lookups/onspd/built_up_area.parquet';
COPY (SELECT 'E92000001' AS code, 'England' AS name) TO 'data/lookups/onspd/country.parquet';
COPY (SELECT 'E99999999' AS code, 'England (UA/MD/LB)' AS name) TO 'data/lookups/onspd/county.parquet';
COPY (SELECT 'E99999999' AS code, 'Not applicable' AS name) TO 'data/lookups/onspd/county_electoral_division.parquet';
COPY (SELECT 'E06000054' AS code, 'Wiltshire' AS name) TO 'data/lookups/onspd/local_authority_district.parquet';
COPY (SELECT 'E12000009' AS code, 'South West' AS name) TO 'data/lookups/onspd/region.parquet';
COPY (SELECT 'D1' AS code, 'Rural town and fringe' AS name) TO 'data/lookups/onspd/rural_urban_11_indicator.parquet';
COPY (SELECT 'E14001356' AS code, 'Melksham and Devizes' AS name) TO 'data/lookups/onspd/westminster_parliamentary_constituency.parquet';
COPY (SELECT 'E05013407' AS code, 'Bradford-on-Avon South' AS name) TO 'data/lookups/onspd/ward.parquet';
COPY (SELECT 'E01034532' AS lsoa21cd, ST_GeomFromText('POLYGON ((-3 51, -2 51, -2 52, -3 52, -3 51))') AS geometry) TO 'data/prepared/lsoas.parquet';
COPY (SELECT 'E02006682' AS msoa21cd, ST_GeomFromText('POLYGON ((-3 51, -2 51, -2 52, -3 52, -3 51))') AS geometry) TO 'data/prepared/msoas.parquet';
COPY (SELECT '100000000001' AS UPRN, 492209.5 AS GRIDGB1E, 240804.25 AS GRIDGB1N,
    'BA15 1DS' AS PCDS, 'E00163467' AS OA21CD, 'E99999999' AS CTY26CD,
    'E99999999' AS CED25CD, 'E06000054' AS LAD26CD, 'E05013407' AS WD26CD,
    'E38000001' AS HLTH19CD, 'E92000001' AS CTRY26CD, 'E12000009' AS RGN26CD,
    'E14001356' AS PCON24CD, 'E30000001' AS EER20CD, 'E30000001' AS TTWA15CD,
    'E06000054' AS ITL25CD, NULL::VARCHAR AS NPARK16CD, 'E01034532' AS LSOA21CD,
    'E02006682' AS MSOA21CD, NULL::VARCHAR AS WZ11CD, 'E38000001' AS SICBL26CD,
    'E63012462' AS BUA24CD, 'E34000001' AS BUASD11CD, 'C1' AS RUC21IND,
    'A1' AS OAC21IND, NULL::VARCHAR AS LEP21CD1, NULL::VARCHAR AS LEP21CD2,
    'E23000026' AS PFA23CD, 28788 AS IMD25IND) TO 'data/downloads/nsul.csv' (HEADER);
COPY (SELECT uprn, gridgb1e, gridgb1n, pcds,
    oa21cd, cty26cd, ced25cd, lad26cd,
    wd26cd, hlth19cd, ctry26cd, rgn26cd,
    pcon24cd, eer20cd, ttwa15cd, itl25cd,
    npark16cd, lsoa21cd, msoa21cd, wz11cd,
    sicbl26cd, bua24cd, buasd11cd, ruc21ind,
    oac21ind, lep21cd1, lep21cd2, pfa23cd,
    imd25ind FROM read_csv('data/downloads/nsul.csv', all_varchar = true)) TO 'data/prepared/nsul.parquet';
CREATE TEMP VIEW nsul_lookup_fixture AS SELECT geography, code, name FROM (VALUES
    ('country', 'E92000001', 'England (NSUL)'),
    ('country', 'W92000004', 'Wales'),
    ('health_area', 'E38000001', 'Test health area'),
    ('european_electoral_region', 'E30000001', 'Test electoral region'),
    ('travel_to_work_area', 'E30000001', 'Test travel area'),
    ('international_territorial_level', 'E06000054', 'Test ITL area'),
    ('lower_super_output_area_21', 'E01034532', 'Test LSOA'),
    ('middle_super_output_area_21', 'E02006682', 'Test MSOA'),
    ('sub_integrated_care_board', 'E38000001', 'Test sub-ICB'),
    ('rural_urban_21', 'C1', 'Test rural classification'),
    ('output_area_classification_21', 'A1', 'Test OAC subgroup'),
    ('output_area_classification_21_group', 'A1', 'Test OAC group'),
    ('output_area_classification_21_supergroup', 'A1', 'Test OAC supergroup'),
    ('police_force_area', 'E23000026', 'Test police force')
) AS lookup(geography, code, name);
COPY (SELECT code, name FROM nsul_lookup_fixture WHERE geography = 'built_up_area_24') TO 'data/lookups/nsul/built_up_area.parquet';
COPY (SELECT code, name FROM nsul_lookup_fixture WHERE geography = 'country') TO 'data/lookups/nsul/country.parquet';
COPY (SELECT code, name FROM nsul_lookup_fixture WHERE geography = 'county') TO 'data/lookups/nsul/county.parquet';
COPY (SELECT code, name FROM nsul_lookup_fixture WHERE geography = 'county_electoral_division') TO 'data/lookups/nsul/county_electoral_division.parquet';
COPY (SELECT code, name FROM nsul_lookup_fixture WHERE geography = 'local_authority_district') TO 'data/lookups/nsul/local_authority_district.parquet';
COPY (SELECT code, name FROM nsul_lookup_fixture WHERE geography = 'region') TO 'data/lookups/nsul/region.parquet';
COPY (SELECT code, name FROM nsul_lookup_fixture WHERE geography = 'ward') TO 'data/lookups/nsul/ward.parquet';
COPY (SELECT code, name FROM nsul_lookup_fixture WHERE geography = 'westminster_parliamentary_constituency') TO 'data/lookups/nsul/westminster_parliamentary_constituency.parquet';
COPY (SELECT code, name FROM nsul_lookup_fixture WHERE geography = 'health_area') TO 'data/lookups/nsul/health_area.parquet';
COPY (SELECT code, name FROM nsul_lookup_fixture WHERE geography = 'european_electoral_region') TO 'data/lookups/nsul/european_electoral_region.parquet';
COPY (SELECT code, name FROM nsul_lookup_fixture WHERE geography = 'travel_to_work_area') TO 'data/lookups/nsul/travel_to_work_area.parquet';
COPY (SELECT code, name FROM nsul_lookup_fixture WHERE geography = 'international_territorial_level') TO 'data/lookups/nsul/international_territorial_level.parquet';
COPY (SELECT code, name FROM nsul_lookup_fixture WHERE geography = 'national_park') TO 'data/lookups/nsul/national_park.parquet';
COPY (SELECT code, name FROM nsul_lookup_fixture WHERE geography = 'lower_super_output_area_21') TO 'data/lookups/nsul/lower_super_output_area_21.parquet';
COPY (SELECT code, name FROM nsul_lookup_fixture WHERE geography = 'middle_super_output_area_21') TO 'data/lookups/nsul/middle_super_output_area_21.parquet';
COPY (SELECT code, name FROM nsul_lookup_fixture WHERE geography = 'sub_integrated_care_board') TO 'data/lookups/nsul/sub_integrated_care_board.parquet';
COPY (SELECT code, name FROM nsul_lookup_fixture WHERE geography = 'rural_urban_21') TO 'data/lookups/nsul/rural_urban_21_indicator.parquet';
COPY (SELECT code, name FROM nsul_lookup_fixture WHERE geography = 'local_enterprise_partnership') TO 'data/lookups/nsul/local_enterprise_partnership.parquet';
COPY (SELECT code, name FROM nsul_lookup_fixture WHERE geography = 'police_force_area') TO 'data/lookups/nsul/police_force_area.parquet';
COPY (SELECT subgroup.code, subgroup.name, parent_group.name AS group_name, supergroup.name AS supergroup_name
    FROM nsul_lookup_fixture subgroup
    LEFT JOIN nsul_lookup_fixture parent_group ON parent_group.geography = 'output_area_classification_21_group' AND parent_group.code = subgroup.code
    LEFT JOIN nsul_lookup_fixture supergroup ON supergroup.geography = 'output_area_classification_21_supergroup' AND supergroup.code = subgroup.code
    WHERE subgroup.geography = 'output_area_classification_21') TO 'data/lookups/nsul/output_area_classification_21.parquet';
SQL

assert_sql() {
    duckdb -bail -noheader -list "$1" -c "LOAD spatial; SELECT CASE WHEN ($2) THEN true ELSE error('Assertion failed: $1') END;"
}

for dataset in onspd nsul all; do
    if [[ "$dataset" == nsul ]]; then
        mv data/lookups/onspd hidden-onspd-lookups
    fi
    for geographies in false true; do
        options=(--dataset "$dataset")
        if "$geographies"; then options+=(--with-boundaries); fi
        output=$dataset-$geographies.duckdb
        bash createdb.sh "${options[@]}" --output "$output"
        assert_sql "$output" "WITH view_columns AS (
            SELECT table_name, column_name,
                lag(column_name) OVER (PARTITION BY table_name ORDER BY ordinal_position) AS previous_column
            FROM information_schema.columns
            WHERE table_name IN ('vw_postcodes', 'vw_uprns')
        ) SELECT count(*) = 0 FROM view_columns
        WHERE ends_with(column_name, '_name') AND previous_column IS DISTINCT FROM CASE column_name
            WHEN 'built_up_area_name' THEN 'built_up_area_24_code'
            WHEN 'rural_urban_21_name' THEN 'rural_urban_21_indicator'
            WHEN 'output_area_classification_21_name' THEN 'output_area_classification_21_indicator'
            WHEN 'output_area_classification_21_group_name' THEN 'output_area_classification_21_name'
            WHEN 'output_area_classification_21_supergroup_name' THEN 'output_area_classification_21_group_name'
            ELSE regexp_replace(column_name, '_name$', '_code') END"
        case "$dataset" in
            onspd) expected_tables=10 ;;
            nsul) expected_tables=21 ;;
            all) expected_tables=23 ;;
        esac
        if "$geographies"; then expected_tables=$((expected_tables + 2)); fi
        assert_sql "$output" "SELECT count(*) = $expected_tables FROM information_schema.tables WHERE table_type = 'BASE TABLE'"
        assert_sql "$output" "SELECT count(*) = 0 FROM information_schema.tables WHERE table_name IN ('postcode', 'nsul', 'vw_nsul', 'nsul_geography_lookup')"
        if [[ "$dataset" != nsul ]]; then
            assert_sql "$output" "SELECT count(*) = 1 FROM vw_postcodes WHERE postcode = 'BA151DS' AND country_name = 'England'"
            assert_sql "$output" "SELECT count(*) = 1 FROM vw_postcodes WHERE postcode = 'BA152DS' AND country_name IS NULL AND county_name IS NULL AND county_electoral_division_name IS NULL AND local_authority_district_name IS NULL AND ward_name IS NULL AND region_name IS NULL AND rural_urban_11_name IS NULL AND westminster_parliamentary_constituency_name IS NULL AND built_up_area_name IS NULL"
            assert_sql "$output" "SELECT count(*) = 2 FROM vw_postcodes"
            assert_sql "$output" "SELECT count(*) = 1 FROM duckdb_indexes() WHERE index_name = 'postcodes_geom_idx'"
            assert_sql "$output" "SELECT count(*) = 1 FROM postcodes WHERE postcode = 'BA151DS' AND ST_X(geometry) = longitude AND ST_Y(geometry) = latitude"
        else
            assert_sql "$output" "SELECT count(*) = 0 FROM information_schema.tables WHERE table_name = 'postcodes'"
        fi
        if [[ "$dataset" != onspd ]]; then
            expected_country=England
            if [[ "$dataset" == nsul ]]; then expected_country='England (NSUL)'; fi
            assert_sql "$output" "SELECT count(*) = 1 FROM vw_uprns WHERE uprn = 100000000001 AND postcode = 'BA151DS' AND easting = 492209.5 AND index_multiple_deprivation_rank = 28788 AND country_name = '$expected_country'"
            assert_sql "$output" "SELECT count(*) = 2 AND count(DISTINCT code) = 2 FROM country"
            assert_sql "$output" "SELECT count(*) = 1 FROM country WHERE code = 'W92000004' AND name = 'Wales'"
            assert_sql "$output" "SELECT count(*) = 1 FROM vw_uprns WHERE health_area_name = 'Test health area' AND european_electoral_region_name = 'Test electoral region' AND travel_to_work_area_name = 'Test travel area' AND international_territorial_level_name = 'Test ITL area' AND lower_super_output_area_21_name = 'Test LSOA' AND middle_super_output_area_21_name = 'Test MSOA' AND sub_integrated_care_board_name = 'Test sub-ICB' AND rural_urban_21_name = 'Test rural classification' AND output_area_classification_21_name = 'Test OAC subgroup' AND output_area_classification_21_group_name = 'Test OAC group' AND output_area_classification_21_supergroup_name = 'Test OAC supergroup' AND police_force_area_name = 'Test police force' AND national_park_name IS NULL AND local_enterprise_partnership_1_name IS NULL"
            assert_sql "$output" "SELECT count(*) = 1 FROM health_area WHERE code = 'E38000001' AND name = 'Test health area'"
            assert_sql "$output" "SELECT count(*) = 1 FROM travel_to_work_area WHERE code = 'E30000001' AND name = 'Test travel area'"
            if [[ "$dataset" == nsul ]]; then
                assert_sql "$output" "SELECT count(*) = 1 FROM vw_uprns WHERE county_name IS NULL"
                assert_sql "$output" "SELECT count(*) = 0 FROM information_schema.tables WHERE table_name = 'rural_urban_11_indicator'"
            else
                assert_sql "$output" "SELECT count(*) = 1 FROM vw_uprns WHERE county_name = 'England (UA/MD/LB)'"
            fi
            assert_sql "$output" "(SELECT data_type = 'UBIGINT' FROM information_schema.columns WHERE table_name = 'uprns' AND column_name = 'uprn') AND (SELECT data_type = 'DOUBLE' FROM information_schema.columns WHERE table_name = 'uprns' AND column_name = 'easting') AND (SELECT data_type = 'INTEGER' FROM information_schema.columns WHERE table_name = 'uprns' AND column_name = 'index_multiple_deprivation_rank')"
        else
            assert_sql "$output" "SELECT count(*) = 0 FROM information_schema.tables WHERE table_name = 'uprns'"
            assert_sql "$output" "SELECT count(*) = 0 FROM information_schema.tables WHERE table_name IN ('health_area', 'travel_to_work_area', 'rural_urban_21_indicator', 'output_area_classification_21')"
        fi
        if "$geographies"; then
            assert_sql "$output" "SELECT count(*) = 1 FROM lower_super_output_area WHERE code = 'E01034532' AND ST_Contains(geometry, ST_Point(-2.25, 51.35))"
            assert_sql "$output" "SELECT count(*) = 1 FROM middle_super_output_area WHERE code = 'E02006682'"
            assert_sql "$output" "SELECT count(*) = 2 FROM duckdb_indexes() WHERE index_name IN ('lsoa_geom_idx', 'msoa_geom_idx')"
        else
            assert_sql "$output" "SELECT count(*) = 0 FROM information_schema.tables WHERE table_name IN ('lower_super_output_area', 'middle_super_output_area')"
        fi
    done
    if [[ "$dataset" == nsul ]]; then
        mv hidden-onspd-lookups data/lookups/onspd
    fi
done

cp data/prepared/onspd.parquet data/custom-postcodes.parquet
cp -R data/lookups/onspd data/custom-onspd-lookups
duckdb -bail -c "COPY (SELECT pcds, doterm, cty25cd, ced25cd,
    lad25cd, wd25cd, east1m, north1m,
    ctry25cd, rgn25cd, pcon24cd, oa11cd,
    lsoa11cd, msoa11cd, bua24cd, ruc11ind,
    imd20ind, oa21cd, lsoa21cd, msoa21cd,
    lat, long FROM read_parquet('data/prepared/onspd.parquet')) TO 'data/custom-postcodes.csv' (HEADER);"
mv data/prepared/onspd.parquet data/default-postcodes.parquet
bash createdb.sh --onspd-file data/custom-postcodes.parquet --onspd-lookups-dir data/custom-onspd-lookups --output custom-postcodes.duckdb
assert_sql custom-postcodes.duckdb "SELECT count(*) = 1 FROM postcodes WHERE postcode = 'BA151DS'"
bash createdb.sh --onspd-file data/custom-postcodes.csv --output custom-postcodes-csv.duckdb
assert_sql custom-postcodes-csv.duckdb "SELECT count(*) = 1 FROM postcodes WHERE postcode = 'BA151DS'"
mv data/default-postcodes.parquet data/prepared/onspd.parquet
if bash createdb.sh --onspd-file data/missing.parquet --output missing-postcodes.duckdb; then exit 1; fi
[[ ! -e missing-postcodes.duckdb ]]

bash createdb.sh --dataset nsul --nsul-file data/prepared/nsul.parquet
[[ -f ons-nsul.duckdb ]]
assert_sql ons-nsul.duckdb 'SELECT count(*) = 1 FROM uprns'
cp -R data/lookups/nsul data/custom-nsul-lookups
bash createdb.sh --dataset nsul --nsul-file data/downloads/nsul.csv --nsul-lookups-dir data/custom-nsul-lookups --output nsul-csv.duckdb
assert_sql nsul-csv.duckdb "SELECT count(*) = 1 FROM uprns WHERE postcode = 'BA151DS'"
if bash createdb.sh --dataset nsul; then exit 1; fi
assert_sql ons-nsul.duckdb 'SELECT count(*) = 1 FROM uprns'
if bash createdb.sh --dataset invalid; then exit 1; fi
if bash createdb.sh --output; then exit 1; fi
if bash createdb.sh --dataset nsul --nsul-file missing.csv --output missing.duckdb; then exit 1; fi
[[ ! -e missing.duckdb ]]

duckdb -bail -c "COPY (SELECT 'bad-uprn' AS uprn, gridgb1e, gridgb1n, pcds,
    oa21cd, cty26cd, ced25cd, lad26cd,
    wd26cd, hlth19cd, ctry26cd, rgn26cd,
    pcon24cd, eer20cd, ttwa15cd, itl25cd,
    npark16cd, lsoa21cd, msoa21cd, wz11cd,
    sicbl26cd, bua24cd, buasd11cd, ruc21ind,
    oac21ind, lep21cd1, lep21cd2, pfa23cd,
    imd25ind FROM read_csv('data/downloads/nsul.csv', all_varchar = true) LIMIT 1) TO 'data/invalid.csv' (HEADER);"
if bash createdb.sh --dataset nsul --nsul-file data/invalid.csv --output invalid.duckdb; then exit 1; fi
[[ ! -e invalid.duckdb ]]
duckdb -bail -c "COPY (WITH one_row AS (SELECT uprn, gridgb1e, gridgb1n, pcds,
    oa21cd, cty26cd, ced25cd, lad26cd,
    wd26cd, hlth19cd, ctry26cd, rgn26cd,
    pcon24cd, eer20cd, ttwa15cd, itl25cd,
    npark16cd, lsoa21cd, msoa21cd, wz11cd,
    sicbl26cd, bua24cd, buasd11cd, ruc21ind,
    oac21ind, lep21cd1, lep21cd2, pfa23cd,
    imd25ind FROM read_csv('data/downloads/nsul.csv', all_varchar = true) LIMIT 1) SELECT uprn, gridgb1e, gridgb1n, pcds,
    oa21cd, cty26cd, ced25cd, lad26cd,
    wd26cd, hlth19cd, ctry26cd, rgn26cd,
    pcon24cd, eer20cd, ttwa15cd, itl25cd,
    npark16cd, lsoa21cd, msoa21cd, wz11cd,
    sicbl26cd, bua24cd, buasd11cd, ruc21ind,
    oac21ind, lep21cd1, lep21cd2, pfa23cd,
    imd25ind FROM one_row UNION ALL SELECT uprn, gridgb1e, gridgb1n, pcds,
    oa21cd, cty26cd, ced25cd, lad26cd,
    wd26cd, hlth19cd, ctry26cd, rgn26cd,
    pcon24cd, eer20cd, ttwa15cd, itl25cd,
    npark16cd, lsoa21cd, msoa21cd, wz11cd,
    sicbl26cd, bua24cd, buasd11cd, ruc21ind,
    oac21ind, lep21cd1, lep21cd2, pfa23cd,
    imd25ind FROM one_row) TO 'data/duplicate.csv' (HEADER);"
if bash createdb.sh --dataset nsul --nsul-file data/duplicate.csv --output duplicate.duckdb; then exit 1; fi
[[ ! -e duplicate.duckdb ]]

bash createdb.sh
[[ -f ons-onspd.duckdb ]]
assert_sql ons-onspd.duckdb 'SELECT count(*) = 2 FROM postcodes'
bash createdb.sh --dataset all
assert_sql ons-all.duckdb 'SELECT count(*) = 1 FROM uprns'
bash createdb.sh --dataset onspd --with-boundaries
bash createdb.sh --dataset nsul --with-boundaries
bash createdb.sh --dataset all --with-boundaries
assert_sql ons-all-boundaries.duckdb 'SELECT count(*) = 1 FROM uprns'
assert_sql ons-all-boundaries.duckdb 'SELECT count(*) = 2 FROM postcodes'
for dataset in onspd nsul all; do
    [[ -f "ons-$dataset.duckdb" && -f "ons-$dataset-boundaries.duckdb" ]]
done

rm data/prepared/lsoas.parquet
if bash createdb.sh --dataset nsul --with-boundaries --output missing-boundary.duckdb; then exit 1; fi
[[ ! -e missing-boundary.duckdb ]]

if bash createdb.sh --dataset nsul --nsul-lookups-dir data/missing-lookups --output missing-lookups.duckdb; then exit 1; fi
[[ ! -e missing-lookups.duckdb ]]

rm data/custom-nsul-lookups/health_area.parquet
if bash createdb.sh --dataset nsul --nsul-lookups-dir data/custom-nsul-lookups --output incomplete-lookups.duckdb; then exit 1; fi
[[ ! -e incomplete-lookups.duckdb ]]
rm data/custom-onspd-lookups/country.parquet
if bash createdb.sh --onspd-lookups-dir data/custom-onspd-lookups --output incomplete-onspd-lookups.duckdb; then exit 1; fi
[[ ! -e incomplete-onspd-lookups.duckdb ]]

printf 'All build profile tests passed.\n'