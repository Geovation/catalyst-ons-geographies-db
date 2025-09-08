# ONS Geography database

This is a repository for storing and querying Office for National Statistics data in the geoparquet file format and importing into a DuckDB database. It initially primarily uses the ONS Postcode Directory (ONSPD) and associated lookups.

## Introduction

[DuckDB](https://duckdb.org/) is a fast in-process database system. It is designed for analytical workloads and can be used as a library in other applications. We are compiling a number of scripts to import ONS geographies into DuckDB, where they will then be available to embed in applications.

The outcome will be to produce and quickly update a duckdb database that can be used to query ONS geographies.

## Setup

- [Duck DB](https://duckdb.org/) CLI - installed via brew
- [PlanetLab's GPQ](https://github.com/planetlabs/gpq) - installed via brew
- [GDAL](https://gdal.org/) - installed via brew

```bash
brew install duckdb
brew install planetlabs/gpq
brew install gdal
```

### Downloading and processing the data

Census boundaries and the ONS postcode directory are downloaded from the ONS Geoportal.

```bash
./download.sh
```

When the downloads are done the data is processed to create a number of geoparquet files.

```bash
./process.sh
```

These are pre-generated as part of this repository, and can be found in the `data` directory.

- `lsoas.parquet` - Lower Super Output Areas
- `msoas.parquet` - Middle Super Output Areas
- `ons_postcode_directory.parquet` - A selection of columns from the ONS Postcode Directory

### Importing the data into DuckDB

The geoparquet files can be imported into DuckDB using a shell script.

```bash
./createpostcodesdb.sh
```

This creates a file named `ons_postcodes.duckdb` which can be used to query the data.

## Release

When a new release is generated in GitHub for this repository, the duckdb database file will be added to the release page as a build item, so there is no need to run the above commands if you simply want the database file.

See the [releases page](https://github.com/Geovation/catalyst-ons-geographies/releases) for the latest release.

## Usage

With duckdb installed the database can be launched:

```
duckdb ons_postcodes.duckdb
```

Whenever loading the database the following commands should be run to enable the geospatial functions:

```
LOAD spatial;
```

### Querying the database

The database can be queried using SQL.

#### Find a postcode

```sql
SELECT * FROM vw_postcodes where replace(postcode, ' ', '') = 'BA151DS';
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
  *
FROM vw_postcodes
WHERE ST_Within(geometry, ST_Buffer(ST_Point(-2.250, 51.346), 0.01))
AND date_of_termination IS NULL
ORDER BY distance ASC LIMIT 1;
```

#### Find multiple postcodes

You can also find multiple postcodes by using the `IN` clause.

```sql
SELECT * FROM vw_postcodes where replace(postcode, ' ', '') IN ('BA151DS', 'BA151DT');
```
