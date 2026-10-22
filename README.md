# ONS geography lookups database

This repository imports Office for National Statistics lookups into DuckDB databases. It supports the ONS Postcode Directory (ONSPD), associated name lookups, the National Statistics UPRN Lookup (NSUL), and optional LSOA/MSOA boundary polygons.

Source dataset names are used for downloading and processing; entity names are used for database tables and loaders:

| Source | Dataset option | Download | Processed input | Database table | Loader | Enriched view |
| --- | --- | --- | --- | --- | --- | --- |
| ONSPD | `onspd` | `data/downloads/onspd.zip` | `data/prepared/onspd.parquet` | `postcodes` | [load_postcodes.sql](load_postcodes.sql) | `vw_postcodes` |
| NSUL | `nsul` | `data/downloads/nsul.zip` | `data/prepared/nsul.parquet` | `uprns` | [load_uprns.sql](load_uprns.sql) | `vw_uprns` |

## Introduction

[DuckDB](https://duckdb.org/) is a fast in-process database system. It is designed for analytical workloads and can be used as a library in other applications. We are compiling number of scripts to import ONS geographies into DuckDB, where they will then be available to embed in applications.

The outcome will be to produce and quickly update a duckdb database that can be used to query ONS geographies.

## Setup

- [DuckDB](https://duckdb.org/) CLI (1.5 or newer) - installed via brew
- [PlanetLab's GPQ](https://github.com/planetlabs/gpq) - installed via brew
- [GDAL](https://gdal.org/) - installed via brew

```bash
brew install duckdb
brew install planetlabs/tap/gpq
brew install gdal
```

### Downloading the data

All three scripts use the source dataset selector `--dataset onspd|nsul|all` and the optional `--with-boundaries` flag. The default is ONSPD without boundaries. For example, download ONSPD, NSUL, or both datasets with boundaries:

```bash
bash download.sh --dataset onspd
bash download.sh --dataset nsul
bash download.sh --dataset all --with-boundaries
```

The default ONS Postcode Directory (ONSPD) download is the August 2026 release, served from a stable [ArcGIS item-data URL](https://www.arcgis.com/sharing/rest/content/items/9e5a92a3cfb14dc7ad43d6ea7a7b8c7f/data). To use another compatible release, get its ZIP download URL from the [ONS Open Geography Portal](https://geoportal.statistics.gov.uk/search?q=ONS%20Postcode%20Directory) and pass it with `--onspd-url URL`; this avoids embedding a short-lived signed URL.

The default NSUL download is the September 2026 ZIP, served from a stable [ArcGIS item-data URL](https://www.arcgis.com/sharing/rest/content/items/03c840334eb3496a97574abe1f86af10/data). Both archives are saved unchanged: ONSPD to `data/downloads/onspd.zip` and NSUL to `data/downloads/nsul.zip`. To use another release, consult the [ONS Open Geography Portal](https://geoportal.statistics.gov.uk/search?q=National%20Statistics%20UPRN%20Lookup), including its user guide and licence terms, and pass the download URL with `--nsul-url URL`. `--nsul-format csv|parquet|zip` selects the download format (default: `zip`). The format is explicit, so signed URLs do not need a filename suffix.

To include the existing 2021 England and Wales LSOA/MSOA boundaries, pass `--with-boundaries`. Use `--lsoa-url URL` and `--msoa-url URL` to override their default GeoJSON URLs. Downloads are staged until all requested transfers succeed, and existing files are protected unless `--force` is supplied. `--force` replaces downloaded files; it does not run processing. Downloads use only `curl`; archive extraction happens during processing.

NSUL covers Great Britain and maps UPRNs to statistical geographies; it is not a full address directory or a guarantee of UK-wide address coverage. It contains third-party intellectual property: check the terms for the chosen release before use or redistribution. Use compatible release vintages when combining NSUL, ONSPD and boundaries; geography codes can change between releases.

### Processing the data

Both ONSPD and NSUL follow the same path: download ZIP, extract CSVs, convert to Parquet, then import into DuckDB. Boundaries follow GeoJSON to GeoParquet to DuckDB. For a complete build:

```bash
bash download.sh --dataset all --with-boundaries
bash process.sh --dataset all --with-boundaries
bash createdb.sh --dataset all --with-boundaries
```

Processing is a separate step. Choose `--dataset onspd|nsul|all` (default: `onspd`) to prepare the selected data, and pass `--with-boundaries` if those files were downloaded. For example:

```bash
bash process.sh --dataset onspd
bash process.sh --dataset nsul
bash process.sh --dataset all --with-boundaries
```

ONSPD processing extracts postcode CSV partitions and name lookups from `data/downloads/onspd.zip`. DuckDB converts the partitions directly to `data/prepared/onspd.parquet`, mapping the release's 2026 geography fields into the stable database columns. Each of its nine geography name tables is written as a normalized CSV and matching Parquet file under `data/lookups/onspd/`. Use `--onspd-file PATH` to select another ONSPD ZIP.

NSUL processing extracts regional `NSUL_*.csv` files from `data/downloads/nsul.zip` and uses DuckDB to combine them directly into `data/prepared/nsul.parquet`. Its bundled documents produce twenty individual geography CSV/Parquet pairs under `data/lookups/nsul/`, including the documented supplements below. Missing lookup documents or conflicting names for the same geography/code fail processing without replacing existing outputs. For a ZIP containing one CSV with a different name, pass `--nsul-member PATH`. Use `--nsul-file PATH` to select a different NSUL ZIP, CSV or Parquet file. CSV input is converted to Parquet; Parquet input is copied unchanged to `data/prepared/nsul.parquet`. Process the release ZIP first to prepare its individual geography files before using standalone CSV or Parquet input.

Processing checks that selected inputs exist before starting. Extraction and conversion use a fresh temporary directory, which is removed on exit. Outputs are moved into `data` only after all selected conversions succeed, so failed conversions leave previous outputs unchanged and repeated runs cannot reuse stale CSV partitions. Tabular processing uses DuckDB and `unzip`; boundaries additionally use GDAL and GPQ to select geography codes and convert GeoJSON to GeoParquet. Each source supplies its own geography files; database loaders use their Parquet versions rather than the legacy root-level `*-codes-filtered.csv` files.

Processing writes Parquet files into `data`. Retain intermediate CSV and Parquet files smaller than 100MB (100,000,000 bytes), including legacy root-level lookup files and the individual lookup pairs. The lookup folders are not ignored by Git. Git ignore rules cannot filter by size, so check file sizes before staging generated data. Large dataset outputs must be generated locally before building a database:

- `lsoas.parquet` - Lower Super Output Areas
- `msoas.parquet` - Middle Super Output Areas
- `onspd.parquet` - A selection of columns from the ONS Postcode Directory
- `nsul.parquet` - A selection of columns from the NSUL
- `onspd-lookups/<table>.csv` and `.parquet` - Individual ONSPD geography names
- `nsul-lookups/<table>.csv` and `.parquet` - Individual NSUL geography names and classification labels

Both sources follow the same geography preparation path: extract CSV, select and normalize columns, write an individual CSV/Parquet pair, then load its Parquet into the corresponding table. For example, each source has a `country.csv` and `country.parquet` in its own lookup folder. These files use `code, name`; the OAC file additionally has `group_name, supergroup_name`. The source folders prevent one release from overwriting the other's names.

Use `--onspd-lookups-dir PATH` and `--nsul-lookups-dir PATH` with `createdb.sh` to select different prepared geography folders. Every required Parquet file is checked before the build starts. The old combined NSUL lookup Parquet and `--nsul-lookups-file` option are no longer used. Existing local data needs processing again, or an explicit conversion to this individual-file layout. The checked-in supplement CSV remains a correction source, not a generated geography output.

All scripts resolve relative paths from the repository directory, even when invoked from elsewhere. Run `bash download.sh --help` or `bash process.sh --help` for the complete options supported by each command.

### Importing the data into DuckDB

[createdb.sh](createdb.sh) creates a database using separate schema definitions and data-loading scripts selected by the build options:

| Schema | Data loader | Contents |
| --- | --- | --- |
| One `tbl_<table>.sql` per shared lookup, e.g. [schema/tbl_country.sql](schema/tbl_country.sql) | [load_onspd_lookups.sql](load_onspd_lookups.sql) | ONSPD geography names: built-up area, country, county, county electoral division, local authority district, region, rural/urban indicator, parliamentary constituency and ward |
| [schema/tbl_postcodes.sql](schema/tbl_postcodes.sql) | [load_postcodes.sql](load_postcodes.sql) | Postcodes loaded from ONSPD |
| [schema/tbl_uprns.sql](schema/tbl_uprns.sql) | [load_uprns.sql](load_uprns.sql) | UPRNs loaded from NSUL |
| One `tbl_<table>.sql` per NSUL geography, e.g. [schema/tbl_health_area.sql](schema/tbl_health_area.sql) | [load_nsul_lookups.sql](load_nsul_lookups.sql) | Shared geography tables plus health areas, electoral regions, travel-to-work areas, ITL/LAU1, national parks, LSOA/MSOA names, sub-ICBs, classifications, LEPs and police-force areas |
| [schema/tbl_lower_super_output_area.sql](schema/tbl_lower_super_output_area.sql), [schema/tbl_middle_super_output_area.sql](schema/tbl_middle_super_output_area.sql) | [load_boundaries.sql](load_boundaries.sql) | LSOA/MSOA boundary polygons |

Each schema file defines one object, following these naming conventions:

- Tables: `tbl_<table>.sql`, including each individual lookup table; primary keys stay with their table definition.
- Views: [schema/vw_postcodes.sql](schema/vw_postcodes.sql) and [schema/vw_uprns.sql](schema/vw_uprns.sql), matching the view names.
- Indexes: `tbl_<table>_indexes.sql`, with separate files for [postcodes](schema/tbl_postcodes_indexes.sql), [lower_super_output_area](schema/tbl_lower_super_output_area_indexes.sql) and [middle_super_output_area](schema/tbl_middle_super_output_area_indexes.sql).

Loaders contain only data inserts. The build creates the required tables, loads their data, then creates spatial indexes and views. Spatial extension setup is handled by the build script when postcodes or boundaries are selected.

There is one table per geography, not one table per source and not a combined lookup table. Both dataset loaders populate the same eight overlapping tables: `built_up_area`, `country`, `county`, `county_electoral_division`, `local_authority_district`, `region`, `westminster_parliamentary_constituency` and `ward`.

| Database choice | Tables created and loaded |
| --- | --- |
| `onspd` | Eight shared geography tables, `rural_urban_11_indicator`, and `postcodes` |
| `nsul` | Eight shared geography tables, twelve additional geography/classification tables, and `uprns`; no ONSPD lookup files are required |
| `all` | The union of both sets, with shared tables created once; ONSPD names take precedence for overlapping codes, and NSUL adds codes not already present |
| `--with-boundaries` | Additionally loads the two boundary geometry tables and creates their spatial indexes |

The 2011 and 2021 rural/urban classifications remain separate because they use different code systems. The OAC table stores subgroup, group and supergroup names together for each classification code. LSOA/MSOA name tables include Scottish equivalents; the optional boundary geometry tables are separate England/Wales inputs. No combined lookup file or lookup database table is loaded.

Run the default postcode build:

```bash
./createdb.sh
```

The default build creates `ons-onspd.duckdb`, containing the `postcodes` table, its name lookups and `vw_postcodes`, without boundary polygons. Each dataset/boundary choice has a distinct default filename; `--output PATH` overrides it.

Choose the datasets and whether to include boundaries independently:

| Contents | Command | Default filename |
| --- | --- | --- |
| Postcodes and name lookups | `bash createdb.sh` | `ons-onspd.duckdb` |
| Postcodes, name lookups and boundaries | `bash createdb.sh --with-boundaries` | `ons-onspd-boundaries.duckdb` |
| UPRNs from NSUL | `bash createdb.sh --dataset nsul` | `ons-nsul.duckdb` |
| UPRNs and boundaries | `bash createdb.sh --dataset nsul --with-boundaries` | `ons-nsul-boundaries.duckdb` |
| Postcodes, name lookups and UPRNs | `bash createdb.sh --dataset all` | `ons-all.duckdb` |
| All datasets and boundaries | `bash createdb.sh --dataset all --with-boundaries` | `ons-all-boundaries.duckdb` |

For different postcode or NSUL input files, or an output path:

```bash
bash createdb.sh --onspd-file data/custom-onspd.csv --dataset all --nsul-file data/NSUL_release.csv --output my_geographies.duckdb
```

`--onspd-file` accepts CSV or Parquet (default: `data/prepared/onspd.parquet`). `process.sh` continues to produce Parquet by default; database creation can also read a CSV directly, like the NSUL import. Paths are relative to the repository directory, or can be absolute. Use distinct `--output` paths to keep multiple builds. An existing output is never overwritten: choose a different `--output` or explicitly remove the old database. Builds are staged in a temporary directory and published only after all imports succeed.

NSUL records are loaded into the `uprns` table and exposed through the `vw_uprns` view, using friendly column names aligned with the `postcodes` table where concepts overlap. `uprn` is an unsigned 64-bit primary key, `easting` and `northing` are doubles, `index_multiple_deprivation_rank` is an integer, and geography identifiers are strings to preserve codes and leading zeros. Missing, invalid or duplicate UPRNs fail the build; invalid numeric values also fail. CSV headers are normalized by DuckDB, and CSV or Parquet inputs must contain the complete Epoch 128 schema.

`vw_uprns` joins the individual geography tables directly by code. The loader reads the corresponding individual Parquet files from `data/lookups/nsul/`; use `--nsul-lookups-dir PATH` to select another compatible release's geography folder. Names are joined with left joins: codes missing from all selected sources retain their UPRN row with null names. Documented unallocated/not-applicable codes have descriptive labels. The September 2026 ZIP supplies:

| NSUL codes | Supplied names |
| --- | --- |
| Country, county, county electoral division, LAD, ward, region, parliamentary constituency, built-up area | Administrative and settlement names |
| Health area, sub-ICB/local health board, European electoral region, travel-to-work area, ITL/LAU1, national park, police-force area | Geography names |
| LSOA/MSOA | England/Wales 2021 names and Scotland 2022 Data Zone/Intermediate Zone names |
| Rural-urban classification | England/Wales descriptions and the separate Scottish classification |
| Output-area classification | Subgroup, group and supergroup labels |
| Both local-enterprise-partnership fields | LEP names |

The nominal 2026 country/county/LAD/region fields use the supplied 2025 code lists; the release guide confirms those codes are unchanged. `ITL25CD` contains LAU1 codes, so its names use `LAU125CD`/`LAU125NM`, not the ITL3 columns in the same document. The supplied travel-to-work lookup is labelled 2011 because it uses 2011 Census data for the areas defined in 2015. OAC codes are matched case-insensitively. Repeated ITL/LAU rows are deduplicated by geography and code.

A full-data audit found omissions in the supplied NSUL documents. [data/source/nsul-geography-supplements.csv](data/source/nsul-geography-supplements.csv) adds documented unallocated/not-applicable labels from the release guide, the guide's `E65000001` non-national-park label, and `E02000781` / Redbridge 031 from the August 2026 ONSPD name list. Each entry records its source. Supplements fill missing codes only; names supplied by the NSUL archive take precedence.

Neither inspected release ZIP supplies separate name lookups for output areas or workplace zones. Those fields remain code-only; they are not assigned invented names. The guide states that the legacy built-up-area-subdivision field is now blank. The deprivation field is a numeric rank, not a name code. Welsh alternative-name columns and Welsh/English variants are not exposed separately; the view uses the standard name column.

`--with-boundaries` adds `lower_super_output_area` and `middle_super_output_area`, each with a primary-key `code` and spatially indexed `geometry` column. These use the existing 2021 England and Wales LSOA/MSOA boundary inputs, not every geography referenced by ONSPD or NSUL. Both ONSPD and NSUL builds populate the shared code/name tables from their own source; NSUL-only builds do not require the postcode directory or its lookup CSVs. Name lookups use left joins, so unmatched postcode and UPRN codes remain in their views with null names. Code-based joins are preferable to spatial joins where the releases share matching codes. Output databases use the DuckDB 1.5 storage format to preserve boundary CRS metadata.

### Data layout

```text
data/
  downloads/       Downloaded ZIP, CSV, Parquet and GeoJSON inputs (ignored)
  prepared/        Prepared dataset and boundary Parquet files
  lookups/
    onspd/         ONSPD geography CSV/Parquet pairs
    nsul/          NSUL geography CSV/Parquet pairs
  source/          Maintained geography supplement CSV (preserved by cleanup)
```

Lookup pairs and boundary Parquet files remain eligible for Git; the large prepared postcode and UPRN datasets are ignored. Existing flat-layout files must be moved into these folders or regenerated with the download and processing scripts.

### Clearing data

Run `bash clean.sh --dry-run` to preview cleanup, then `bash clean.sh` to delete downloaded and prepared data (including CSV/Parquet lookups and boundaries) and databases. It preserves [data/source/nsul-geography-supplements.csv](data/source/nsul-geography-supplements.csv), which is maintained source data. Tracked generated files will appear as deleted in Git after cleanup.

Database cleanup covers `*.duckdb` and `*.duckdb.wal` files directly in the repository root and `dist/`. Custom outputs elsewhere, release logs and checksum manifests are left untouched; regenerate manifests before publishing another release. Stop any active downloads, processing or database sessions before cleaning.

### Testing

```bash
bash tests/clean.sh
bash tests/preparation.sh
bash tests/build.sh
```

Preparation tests use local fixture URLs in a temporary directory to check all six download profiles, CSV/Parquet/ZIP NSUL downloads, overwrite protection, failure cleanup, stale-partition isolation, both ONSPD archive layouts, repeated boundary conversion, all bundled NSUL lookup types, Scottish names, conflicting lookup rejection, and a combined database build. They require `curl`, `zip`, `unzip`, GDAL, GPQ and DuckDB with its Spatial extension, but do not download full datasets. Build tests cover all six database profiles, lookup and spatial queries, CSV/Parquet postcode and NSUL imports, missing lookup inputs, and import failure safety.

Some fixture tests deliberately print errors for invalid arguments, missing inputs, invalid or duplicate UPRNs, conflicting names and existing outputs. The test scripts require these commands to fail. A successful suite exits with status zero and ends with `All preparation tests passed.` or `All build profile tests passed.` These expected test diagnostics must not be confused with errors during a production build.

Run `bash download.sh --help`, `bash process.sh --help` or `bash createdb.sh --help` for the options supported at each stage.

## Release

### Clean rebuild

Run the following from the repository root. It deliberately deletes all downloaded, generated and legacy files under `data`, including old tracked lookup files, but preserves [data/source/nsul-geography-supplements.csv](data/source/nsul-geography-supplements.csv), which is maintained source data. The tests generate their own fixtures and do not depend on the deleted files.

The six databases are written to `dist`, ready to attach as separate GitHub release assets. Use a new `release_dir` for another release; existing databases are never overwritten. The shell must preserve pipeline failures so logging with `tee` cannot hide a failed download, conversion or build.

```bash
bash <<'BASH'
set -euo pipefail
release_dir=dist
mkdir -p "$release_dir/logs"

for dataset in onspd nsul all; do
  for suffix in '' '-boundaries'; do
    output="$release_dir/ons-$dataset$suffix.duckdb"
    if [[ -e "$output" ]]; then
      printf 'Output already exists: %s; choose a new release_dir.\n' "$output" >&2
      exit 1
    fi
  done
done

test -s data/source/nsul-geography-supplements.csv
find data -mindepth 1 -maxdepth 1 ! -name source -exec rm -rf -- {} +
bash download.sh --dataset all --with-boundaries 2>&1 | tee "$release_dir/logs/download.log"
bash process.sh --dataset all --with-boundaries 2>&1 | tee "$release_dir/logs/process.log"

for dataset in onspd nsul all; do
  for boundaries in false true; do
    options=(--dataset "$dataset")
    filename="ons-$dataset"
    if "$boundaries"; then
      options+=(--with-boundaries)
      filename+=-boundaries
    fi
    filename+=.duckdb
    output="$release_dir/$filename"
    bash createdb.sh "${options[@]}" --output "$output" 2>&1 | tee "$release_dir/logs/$filename.log"

    if [[ "$dataset" != nsul ]]; then
      duckdb -readonly -bail "$output" -c "LOAD spatial;
        SELECT CASE WHEN (SELECT count(*) FROM postcodes) = (SELECT count(*) FROM read_parquet('data/prepared/onspd.parquet'))
        AND (SELECT count(*) FROM vw_postcodes) = (SELECT count(*) FROM postcodes)
        THEN true ELSE error('Postcode import/view mismatch') END AS postcodes_verified;" \
        2>&1 | tee -a "$release_dir/logs/$filename.verify.log"
    fi
    if [[ "$dataset" != onspd ]]; then
      duckdb -readonly -bail "$output" -c "SELECT CASE WHEN
        (SELECT count(*) FROM uprns) = (SELECT count(*) FROM read_parquet('data/prepared/nsul.parquet'))
        AND (SELECT count(*) FROM vw_uprns) = (SELECT count(*) FROM uprns)
        THEN true ELSE error('UPRN import/view mismatch') END AS uprns_verified;" \
        2>&1 | tee -a "$release_dir/logs/$filename.verify.log"
    fi
    if "$boundaries"; then
      duckdb -readonly -bail "$output" -c "LOAD spatial; SELECT CASE WHEN
        (SELECT count(*) FROM lower_super_output_area) = (SELECT count(*) FROM read_parquet('data/prepared/lsoas.parquet'))
        AND (SELECT count(*) FROM middle_super_output_area) = (SELECT count(*) FROM read_parquet('data/prepared/msoas.parquet'))
        THEN true ELSE error('Boundary import mismatch') END AS boundaries_verified;" \
        2>&1 | tee -a "$release_dir/logs/$filename.verify.log"
    fi
  done
done

scan_result=0
grep -Ein '(^|[^[:alpha:]])(error|fatal|exception|warning|failed)([^[:alpha:]]|$)' "$release_dir"/logs/*.log || scan_result=$?
if [[ "$scan_result" -ne 1 ]]; then
  printf 'Diagnostics found, or log scan failed; review production logs before publishing.\n' >&2
  exit 1
fi

pushd "$release_dir" >/dev/null
shasum -a 256 ./*.duckdb > SHA256SUMS
shasum -a 256 -c SHA256SUMS
popd >/dev/null
BASH
```

The current source releases are ONSPD August 2026, NSUL September 2026 / Epoch 128, and 2021 England/Wales LSOA/MSOA boundaries. A clean full-data rebuild on 21 October 2026 with DuckDB 1.5.6 produced and verified all six databases:

| Data | Verified rows in each applicable database |
| --- | ---: |
| Postcodes | 2,729,089 |
| UPRNs | 41,593,127 |
| LSOA boundaries | 35,672 |
| MSOA boundaries | 7,264 |

The rebuild also checked the selected base-table counts (10 for ONSPD, 21 for NSUL, 23 for both, plus two with boundaries), the expected spatial indexes, and that enriched views did not lose or duplicate source rows. Production processing, build and verification logs contained no error or warning diagnostics. Counts describe these specific releases, not future downloads.

### Publishing assets

Attach the six distinctly named `dist/ons-*.duckdb` files and `dist/SHA256SUMS` to the GitHub release. The scripts build local artifacts; they do not create or publish a GitHub release automatically. For an existing release, the optional GitHub CLI command is:

```bash
gh release upload YOUR_RELEASE_TAG dist/ons-*.duckdb dist/SHA256SUMS
```

Check the licences and redistribution terms, especially those applying to NSUL, before publishing. Each GitHub release asset must remain below 2 GiB; all six current files meet that limit, but the combined boundary database is close to it (2,137,272,320 bytes). For larger future releases, distribute gzip-compressed databases and calculate checksums for those compressed assets instead. The raw database must be decompressed before opening it with DuckDB.

After downloading release assets together, verify them with `shasum -a 256 -c SHA256SUMS`. Choose the smallest database containing the required datasets. Build logs are retained locally under `dist/logs/`; generated data and release outputs are not intended to be committed to Git.

See the [releases page](https://github.com/Geovation/catalyst-ons-geographies/releases) for the latest release.

## Usage

With duckdb installed the database can be launched:

```bash
duckdb ons-onspd.duckdb
```

For postcode or boundary databases, load the spatial extension to enable geospatial functions. NSUL-only databases do not require it:

```sql
LOAD spatial;
```

### Querying the database

The database can be queried using SQL.

#### Find a UPRN

In any database built with NSUL:

```sql
SELECT uprn, postcode, easting, northing, country_code, country_name,
  lower_super_output_area_21_code, lower_super_output_area_21_name
FROM vw_uprns
WHERE uprn = 100000000001;
```

#### Find a postcode

```sql
SELECT postcode, date_of_termination, county_code, county_name,
  county_electoral_division_code, county_electoral_division_name,
  local_authority_district_code, local_authority_district_name, ward_code, ward_name,
  easting, northing, country_code, country_name, region_code, region_name,
  westminster_parliamentary_constituency_code, westminster_parliamentary_constituency_name,
  output_area_11_code, lower_super_output_area_11_code, middle_super_output_area_11_code,
  built_up_area_24_code, built_up_area_name, rural_urban_11_code, rural_urban_11_name,
  index_multiple_deprivation_rank, output_area_21_code, lower_super_output_area_21_code,
  middle_super_output_area_21_code, longitude, latitude, geometry
FROM vw_postcodes
WHERE replace(postcode, ' ', '') = 'BA151DS';
```

The results of the above query would be:

| Column Name                                 | Value                                 |
| ------------------------------------------- | ------------------------------------- |
| postcode                                    | BA15 1DS                              |
| date_of_termination                         |                                       |
| county_code                                 | E99999999                             |
| county_name                                 | (pseudo) England (UA/MD/LB)           |
| county_electoral_division_code              | E99999999                             |
| county_electoral_division_name              |                                       |
| local_authority_district_code               | E06000054                             |
| local_authority_district_name               | Wiltshire                             |
| ward_code                                   | E05013407                             |
| ward_name                                   | Bradford-on-Avon South                |
| easting                                     | 382678                                |
| northing                                    | 160818                                |
| country_code                                | E92000001                             |
| country_name                                | England                               |
| region_code                                 | E12000009                             |
| region_name                                 | South West                            |
| westminster_parliamentary_constituency_code | E14001356                             |
| westminster_parliamentary_constituency_name | Melksham and Devizes                  |
| output_area_11_code                         | E00163467                             |
| lower_super_output_area_11_code             | E01032050                             |
| middle_super_output_area_11_code            | E02006682                             |
| built_up_area_24_code                       | E63012462                             |
| built_up_area_name                          | Bradford-on-Avon                      |
| rural_urban_11_code                         | D1                                    |
| rural_urban_11_name                         | (England/Wales) Rural town and fringe |
| index_multiple_deprivation_rank             | 27325                                 |
| output_area_21_code                         | E00163467                             |
| lower_super_output_area_21_code             | E01034532                             |
| middle_super_output_area_21_code            | E02006682                             |
| longitude                                   | -2.250094                             |
| latitude                                    | 51.346176                             |
| geometry                                    | POINT (-2.250094 51.346176)           |

#### Find a postcode by point

It is also possible to reverse geocode and find the postcode and associated ONS data for a given point. It's important to note that as the ONS postcode lookup is best fit, the results may not be 100% accurate for the given point. The following query uses the date_of_termination field to filter out postcodes that are no longer in use.

```sql
SELECT
  st_distance(ST_Point(-2.250, 51.346), geometry) as distance,
  postcode, local_authority_district_code, local_authority_district_name,
  country_code, country_name, longitude, latitude
FROM vw_postcodes
WHERE ST_Within(geometry, ST_Buffer(ST_Point(-2.250, 51.346), 0.01))
AND date_of_termination IS NULL
ORDER BY distance ASC LIMIT 1;
```

#### Find multiple postcodes

You can also find multiple postcodes by using the `IN` clause.

```sql
SELECT postcode, local_authority_district_code, local_authority_district_name,
  country_code, country_name
FROM vw_postcodes
WHERE replace(postcode, ' ', '') IN ('BA151DS', 'BA151DT');
```
