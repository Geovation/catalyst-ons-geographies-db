#!/bin/bash
set -euo pipefail

repository=$(cd "$(dirname "$0")/.." && pwd)
workspace=$(mktemp -d)
trap 'rm -rf "$workspace"' EXIT
cp "$repository/download.sh" "$repository/process.sh" "$workspace/"
cp "$repository/createdb.sh" "$repository"/load_*.sql "$workspace/"
cp -R "$repository/schema" "$workspace/"
mkdir -p "$workspace/source/Data/multi_csv" "$workspace/source/Documents"
cd "$workspace/source"
write_nsul_fixture() {
    printf '%s\n%s\n' \
        'UPRN,GRIDGB1E,GRIDGB1N,PCDS,OA21CD,CTY26CD,CED25CD,LAD26CD,WD26CD,HLTH19CD,CTRY26CD,RGN26CD,PCON24CD,EER20CD,TTWA15CD,ITL25CD,NPARK16CD,LSOA21CD,MSOA21CD,WZ11CD,SICBL26CD,BUA24CD,BUASD11CD,RUC21IND,OAC21IND,LEP21CD1,LEP21CD2,PFA23CD,IMD25IND' \
        "$1,492209.5,240804.25,BA15 1DS,E00163467,E99999999,E99999999,E06000054,E05013407,E38000001,${5:-E92000001},E12000009,E14001356,E30000001,E30000001,E06000054,,${2},${3},,E38000001,E63012462,E34000001,${6:-C1},A1,,,E23000026,28788" \
        > "$4"
}
write_nsul_fixture 100000000001 E01034532 E02006682 nsul.csv
duckdb -bail -c "COPY (SELECT uprn, gridgb1e, gridgb1n, pcds,
    oa21cd, cty26cd, ced25cd, lad26cd,
    wd26cd, hlth19cd, ctry26cd, rgn26cd,
    pcon24cd, eer20cd, ttwa15cd, itl25cd,
    npark16cd, lsoa21cd, msoa21cd, wz11cd,
    sicbl26cd, bua24cd, buasd11cd, ruc21ind,
    oac21ind, lep21cd1, lep21cd2, pfa23cd,
    imd25ind FROM read_csv('nsul.csv', all_varchar = true)) TO 'nsul.parquet';"
printf '%s\n' \
    'pcds,doterm,cty26cd,ced25cd,lad26cd,wd26cd,east1m,north1m,ctry26cd,rgn26cd,pcon24cd,oa11cd,lsoa11cd,msoa11cd,bua24cd,ruc11ind,imd25ind,oa21cd,lsoa21cd,msoa21cd,lat,long' \
    'BA15 1DS,,E99999999,E99999999,E06000054,E05013407,382678,160818,E92000001,E12000009,E14001356,E00163467,E01032050,E02006682,E63012462,D1,27325,E00163467,E01034532,E02006682,51.346176,-2.250094' \
    > Data/multi_csv/ONSPD_AUG_2026_UK_AB.csv
printf '%s\n' \
    'pcds,doterm,cty26cd,ced25cd,lad26cd,wd26cd,east1m,north1m,ctry26cd,rgn26cd,pcon24cd,oa11cd,lsoa11cd,msoa11cd,bua24cd,ruc11ind,imd25ind,oa21cd,lsoa21cd,msoa21cd,lat,long' \
    'BA15 2DS,,E99999999,E99999999,E06000054,E05013407,382679,160819,E92000001,E12000009,E14001356,E00163468,E01032051,E02006683,E63012462,D1,27326,E00163468,E01000001,E02000001,51.347176,-2.251094' \
    > Data/multi_csv/ONSPD_AUG_2026_UK_BA.csv
while IFS='|' read -r member header row; do
    printf '%s\n%s\n' "$header" "$row" > "Documents/$member.csv"
done <<'LOOKUPS'
BUA Built Up Area names and codes UK|BUA24CD,BUA24NM|E63012462,Bradford-on-Avon
CTRY Country names and codes UK|CTRY25CD,CTRY25NM|E92000001,England
CTY County names and codes UK|CTY25CD,CTY25NM|E99999999,(pseudo) England (UA/MD/LB)
CED County Electoral Division names and codes UK|CED25CD,CED25NM|E99999999,Not applicable
LAD Local Authority District names and codes UK|LAD25CD,LAD25NM|E06000054,Wiltshire
RGN Region names and codes UK|RGN25CD,RGN25NM|E12000009,South West
RUC11 Rural Urban (2011) Indicator names and codes UK|RU11IND,RU11NM|D1,Rural town and fringe
PCON Westminster Parliamentary Constituency names and codes UK|PCON24CD,PCON24NM|E14001356,Melksham and Devizes
LOOKUPS
printf 'S92000003,Scotland\n' >> 'Documents/CTRY Country names and codes UK.csv'
printf 'WD26CD,WD26NM\nE05013407,Bradford-on-Avon South\n' > 'Documents/WD Ward names and codes UK as at 05_26.csv'
zip -q -r postcodes.zip Data Documents
cp Data/multi_csv/ONSPD_AUG_2026_UK_AB.csv Data/ONSPD_TEST.csv
zip -q -r postcodes-single.zip Data/ONSPD_TEST.csv Documents
zip -q nsul-no-lookups.zip nsul.csv
while IFS='|' read -r member header row; do
    printf '%s\n%s\n' "$header" "$row" > "Documents/$member.csv"
done <<'NSUL_LOOKUPS'
HLTH_names and codes UK|HLTHAUCD,HLTHAUNM|E38000001,Test health area
EER names and codes UK|EER10CD,EER10NM|E30000001,Test electoral region
TTWA_names and codes UK|TTWA11CD,TTWA11NM|E30000001,Test travel area
ITL125_ITL225_ITL325_LAU125_LAD24_UK_LU|ITL325CD,ITL325NM,LAU125CD,LAU125NM|TLK15,Test ITL3 area,E06000054,Test LAU1 area
NPARK_National Park names and codes GB|NPARK16CD,NPARK16NM|E26000001,Test national park
LSOA21 2021 LSOA names and codes EW|LSOA21CD,LSOA21NM|E01034532,Test LSOA
LSOA21 2022 DZ names and codes SC|DZ22CD,DZ22NM|S01000001,Test Scottish data zone
MSOA21 2021 MSOA names and codes EW|MSOA21CD,MSOA21NM|E02006682,Test MSOA
MSOA21 2022 IZ names and codes SC|IZ22CD,IZ22NM|S02000001,Test Scottish intermediate zone
SICBL Sub_ICB names and codes UK|SICBL26CD,SICBL26NM|E38000001,Test sub-ICB
RUC21 Rural Urban Indicator names and codes EW|RUC21IND,RUC21DESC,Urban_rural_flag|C1,Test EW rural classification,Rural
RUC21 Rural Urban Indicator names and codes SC|RUC21IND,RUC21DESC|1,Test Scottish rural classification
OAC21 names and codes UK|OAC21IND,Supergroup,Group,Subgroup|a1,Test OAC supergroup,Test OAC group,Test OAC subgroup
LEP_names and codes EN|LEP21CD,LEP21NM|E37000001,Test enterprise partnership
PFA Police Force Area names and codes UK|PFA23CD,PFA23NM|E23000026,Test police force
NSUL_LOOKUPS
printf 'TLK15,Test ITL3 area,E06000054,Test LAU1 area\n' >> Documents/ITL125_ITL225_ITL325_LAU125_LAD24_UK_LU.csv
zip -q -r nsul.zip nsul.csv Documents
mkdir NSUL
write_nsul_fixture 100000000001 E01034532 E02006682 NSUL/NSUL_TEST_EE.csv
write_nsul_fixture 100000000002 S01000001 S02000001 NSUL/NSUL_TEST_SC.csv S92000003 1
zip -q -r nsul-auto.zip NSUL Documents
printf 'RUC21IND,RUC21DESC\nC1,Conflicting rural label\n' > Documents/RUC21_CONFLICT.csv
zip -q -r nsul-conflicting.zip NSUL Documents
rm Documents/RUC21_CONFLICT.csv
for area in lsoa msoa; do
    if [[ "$area" == lsoa ]]; then code=E01034532; else code=E02006682; fi
    printf '{"type":"FeatureCollection","features":[{"type":"Feature","properties":{"%s21cd":"%s"},"geometry":{"type":"Polygon","coordinates":[[[-3,51],[-2,51],[-2,52],[-3,52],[-3,51]]]}}]}\n' \
        "$area" "$code" > "$area.geojson"
done
source_url=file://$workspace/source

expect_failure() {
    if "$@"; then
        printf 'Expected failure: %s\n' "$*" >&2
        exit 1
    fi
}

assert_lookup_files() {
    local source=$1 expected=$2 parquet_file csv_file columns
    local -a lookup_files
    lookup_files=(data/lookups/"$source"/*.csv)
    [[ ${#lookup_files[@]} -eq "$expected" ]]
    lookup_files=(data/lookups/"$source"/*.parquet)
    [[ ${#lookup_files[@]} -eq "$expected" ]]
    for parquet_file in "${lookup_files[@]}"; do
        csv_file=${parquet_file%.parquet}.csv
        [[ -f "$csv_file" ]]
        columns='code, name'
        if [[ "$parquet_file" == */output_area_classification_21.parquet ]]; then
            columns='code, name, group_name, supergroup_name'
        fi
        LOOKUP_CSV="$csv_file" LOOKUP_PARQUET="$parquet_file" duckdb -bail -noheader -list -c "
            SELECT CASE WHEN count(*) = 0 THEN true ELSE error('CSV/Parquet lookup mismatch') END
            FROM (
                (SELECT $columns FROM read_csv(getenv('LOOKUP_CSV'), header = true, delim = ',', all_varchar = true)
                 EXCEPT ALL SELECT $columns FROM read_parquet(getenv('LOOKUP_PARQUET')))
                UNION ALL
                (SELECT $columns FROM read_parquet(getenv('LOOKUP_PARQUET'))
                 EXCEPT ALL SELECT $columns FROM read_csv(getenv('LOOKUP_CSV'), header = true, delim = ',', all_varchar = true))
            );"
    done
}

cd "$workspace"
for script in download process; do
    bash "$script.sh" --help
    expect_failure bash "$script.sh" --dataset invalid
    expect_failure bash "$script.sh" --dataset
    expect_failure bash "$script.sh" --unknown
done
expect_failure bash download.sh --dataset nsul --nsul-url "$source_url/nsul.csv" --nsul-format invalid
expect_failure bash download.sh --dataset all --onspd-url "$source_url/postcodes.zip" --nsul-url "$source_url/missing.csv"
[[ ! -e data/downloads/onspd.zip && ! -e data/downloads/nsul.zip ]]

for dataset in onspd nsul all; do
    for geographies in false true; do
        rm -rf data
        options=(--dataset "$dataset" --onspd-url "$source_url/postcodes.zip"
            --nsul-url "$source_url/nsul-auto.zip" --lsoa-url "$source_url/lsoa.geojson"
            --msoa-url "$source_url/msoa.geojson")
        if "$geographies"; then options+=(--with-boundaries); fi
        bash download.sh "${options[@]}"
        mkdir -p data/source
        cp "$repository/data/source/nsul-geography-supplements.csv" data/source/
        if [[ "$dataset" != nsul ]]; then
            cmp source/postcodes.zip data/downloads/onspd.zip
        else
            [[ ! -e data/downloads/onspd.zip ]]
        fi
        if [[ "$dataset" != onspd ]]; then
            cmp source/nsul-auto.zip data/downloads/nsul.zip
        else
            [[ ! -e data/downloads/nsul.zip ]]
        fi
        [[ ! -e data/downloads/nsul.csv && ! -e data/prepared/nsul.parquet ]]
        if "$geographies"; then
            cmp source/lsoa.geojson data/downloads/lsoas.geojson
            cmp source/msoa.geojson data/downloads/msoas.geojson
        else
            [[ ! -e data/downloads/lsoas.geojson && ! -e data/downloads/msoas.geojson ]]
        fi
    done
done

expect_failure bash download.sh --dataset nsul --nsul-url "$source_url/nsul.csv"
expect_failure bash download.sh --dataset all --onspd-url "$source_url/nsul.zip" \
    --nsul-url "$source_url/missing.csv" --force
cmp source/nsul-auto.zip data/downloads/nsul.zip
cmp source/postcodes.zip data/downloads/onspd.zip
bash download.sh --dataset nsul --nsul-url "$source_url/nsul.zip" --force
cmp source/nsul.zip data/downloads/nsul.zip
bash process.sh --dataset nsul --nsul-member nsul.csv
duckdb -bail -noheader -list -c "SELECT CASE WHEN count(*) = 1 THEN true ELSE error('NSUL member extraction failed') END FROM read_parquet('data/prepared/nsul.parquet');"
bash download.sh --dataset nsul --nsul-url "$source_url/nsul-auto.zip" --nsul-format zip --force
bash process.sh --dataset nsul
duckdb -bail -noheader -list -c "SELECT CASE WHEN count(*) = 2 THEN true ELSE error('NSUL regional CSV merge failed') END FROM read_parquet('data/prepared/nsul.parquet');"
nsul_lookup_files=(data/lookups/nsul/*.parquet)
[[ ${#nsul_lookup_files[@]} -eq 20 && ! -e data/nsul-geography-lookups.parquet ]]
duckdb -bail -noheader -list -c "SELECT CASE WHEN count(*) = 1 THEN true ELSE error('NSUL lookup deduplication failed') END FROM read_parquet('data/lookups/nsul/international_territorial_level.parquet');"
cp -R data/lookups/nsul source/prepared-nsul-lookups
expect_failure bash process.sh --dataset nsul --nsul-file source/nsul-no-lookups.zip --nsul-member nsul.csv
diff -r source/prepared-nsul-lookups data/lookups/nsul
expect_failure bash process.sh --dataset nsul --nsul-file source/nsul-conflicting.zip
diff -r source/prepared-nsul-lookups data/lookups/nsul
expect_failure bash process.sh --dataset nsul --nsul-member missing.csv
duckdb -bail -noheader -list -c "SELECT CASE WHEN count(*) = 2 THEN true ELSE error('Failed ZIP processing changed NSUL Parquet') END FROM read_parquet('data/prepared/nsul.parquet');"
bash download.sh --dataset nsul --nsul-url "$source_url/nsul.csv" --nsul-format csv
cmp source/nsul.csv data/downloads/nsul.csv
bash download.sh --dataset nsul --nsul-url "$source_url/nsul.parquet" --nsul-format parquet --force
cmp source/nsul.parquet data/downloads/nsul.parquet
bash process.sh --dataset nsul --nsul-file data/downloads/nsul.csv
[[ -f data/prepared/nsul.parquet ]]
duckdb -bail -noheader -list -c "SELECT CASE WHEN count(*) = 1 THEN true ELSE error('NSUL CSV-to-Parquet conversion failed') END FROM read_parquet('data/prepared/nsul.parquet');"
bash process.sh --dataset nsul --nsul-file data/prepared/nsul.parquet
expect_failure bash process.sh --dataset nsul --nsul-file missing.csv
expect_failure bash process.sh --dataset nsul --nsul-file data/downloads/onspd.zip
rm data/downloads/lsoas.geojson
expect_failure bash process.sh --dataset nsul --with-boundaries
duckdb -bail -noheader -list -c "SELECT CASE WHEN count(*) = 1 THEN true ELSE error('Missing boundary changed NSUL output') END FROM read_parquet('data/prepared/nsul.parquet');"
[[ -z "$(find data -name 'download.*' -print)" ]]

mkdir -p data/onspd-parts
cp source/Data/multi_csv/ONSPD_AUG_2026_UK_AB.csv data/onspd-parts/stale.csv
bash process.sh --dataset all
assert_lookup_files onspd 9
assert_lookup_files nsul 20
duckdb -bail -noheader -list -c "SELECT CASE WHEN count(*) = 2 AND min(pcds) = 'BA15 1DS' THEN true ELSE error('Postcode conversion failed') END FROM read_parquet('data/prepared/onspd.parquet');"
cp data/prepared/onspd.parquet source/prepared-postcodes.parquet
expect_failure bash process.sh --dataset all --nsul-member missing.csv
cmp source/prepared-postcodes.parquet data/prepared/onspd.parquet
bash process.sh --dataset onspd --onspd-file source/postcodes-single.zip
duckdb -bail -noheader -list -c "SELECT CASE WHEN count(*) = 1 THEN true ELSE error('Single-file ONSPD conversion failed') END FROM read_parquet('data/prepared/onspd.parquet');"
[[ ! -e data/prepared/lsoas.parquet && ! -e data/prepared/msoas.parquet ]]
cp source/lsoa.geojson data/downloads/lsoas.geojson
bash process.sh --dataset nsul --with-boundaries
bash process.sh --dataset all --with-boundaries
[[ -z "$(find data -name 'process.*' -print)" ]]
bash createdb.sh --dataset all --with-boundaries
duckdb -bail -noheader -list ons-all-boundaries.duckdb <<'SQL'
LOAD spatial;
SELECT CASE WHEN count(*) = 1 THEN true ELSE error('Combined import failed') END
FROM vw_uprns n
JOIN lower_super_output_area l ON n.lower_super_output_area_21_code = l.code
JOIN middle_super_output_area m ON n.middle_super_output_area_21_code = m.code
JOIN postcodes p ON p.lower_super_output_area_21_code = l.code
WHERE ST_Contains(l.geometry, ST_Point(p.longitude, p.latitude));
SELECT CASE WHEN count(*) = 1 THEN true ELSE error('NSUL extra geography names failed') END
FROM vw_uprns
WHERE uprn = 100000000001 AND health_area_name = 'Test health area'
    AND county_name = '(pseudo) England (UA/MD/LB)'
    AND travel_to_work_area_name = 'Test travel area'
    AND international_territorial_level_name = 'Test LAU1 area'
    AND lower_super_output_area_21_name = 'Test LSOA'
    AND middle_super_output_area_21_name = 'Test MSOA'
    AND rural_urban_21_name = 'Test EW rural classification'
    AND output_area_classification_21_name = 'Test OAC subgroup'
    AND output_area_classification_21_group_name = 'Test OAC group'
    AND output_area_classification_21_supergroup_name = 'Test OAC supergroup';
SELECT CASE WHEN count(*) = 1 THEN true ELSE error('Scottish NSUL geography names failed') END
FROM vw_uprns
WHERE uprn = 100000000002 AND country_name = 'Scotland'
    AND lower_super_output_area_21_name = 'Test Scottish data zone'
    AND middle_super_output_area_21_name = 'Test Scottish intermediate zone'
    AND rural_urban_21_name = 'Test Scottish rural classification';
SELECT CASE WHEN count(*) = 1 THEN true ELSE error('Documented NSUL lookup supplement missing') END
FROM middle_super_output_area_21
WHERE code = 'E02000781' AND name = 'Redbridge 031';
SQL
printf 'All preparation tests passed.\n'