INSERT INTO built_up_area
SELECT code, name FROM read_parquet(getenv('ONSPD_LOOKUPS_DIR') || '/built_up_area.parquet');

INSERT INTO country
SELECT code, name FROM read_parquet(getenv('ONSPD_LOOKUPS_DIR') || '/country.parquet');

INSERT INTO county
SELECT code, name FROM read_parquet(getenv('ONSPD_LOOKUPS_DIR') || '/county.parquet');

INSERT INTO county_electoral_division
SELECT code, name FROM read_parquet(getenv('ONSPD_LOOKUPS_DIR') || '/county_electoral_division.parquet');

INSERT INTO local_authority_district
SELECT code, name FROM read_parquet(getenv('ONSPD_LOOKUPS_DIR') || '/local_authority_district.parquet');

INSERT INTO region
SELECT code, name FROM read_parquet(getenv('ONSPD_LOOKUPS_DIR') || '/region.parquet');

INSERT INTO rural_urban_11_indicator
SELECT code, name FROM read_parquet(getenv('ONSPD_LOOKUPS_DIR') || '/rural_urban_11_indicator.parquet');

INSERT INTO westminster_parliamentary_constituency
SELECT code, name FROM read_parquet(getenv('ONSPD_LOOKUPS_DIR') || '/westminster_parliamentary_constituency.parquet');

INSERT INTO ward
SELECT code, name FROM read_parquet(getenv('ONSPD_LOOKUPS_DIR') || '/ward.parquet');