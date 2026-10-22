INSERT INTO built_up_area
SELECT code, name FROM read_parquet(getenv('NSUL_LOOKUPS_DIR') || '/built_up_area.parquet')
ON CONFLICT (code) DO NOTHING;

INSERT INTO country
SELECT code, name FROM read_parquet(getenv('NSUL_LOOKUPS_DIR') || '/country.parquet')
ON CONFLICT (code) DO NOTHING;

INSERT INTO county
SELECT code, name FROM read_parquet(getenv('NSUL_LOOKUPS_DIR') || '/county.parquet')
ON CONFLICT (code) DO NOTHING;

INSERT INTO county_electoral_division
SELECT code, name FROM read_parquet(getenv('NSUL_LOOKUPS_DIR') || '/county_electoral_division.parquet')
ON CONFLICT (code) DO NOTHING;

INSERT INTO local_authority_district
SELECT code, name FROM read_parquet(getenv('NSUL_LOOKUPS_DIR') || '/local_authority_district.parquet')
ON CONFLICT (code) DO NOTHING;

INSERT INTO region
SELECT code, name FROM read_parquet(getenv('NSUL_LOOKUPS_DIR') || '/region.parquet')
ON CONFLICT (code) DO NOTHING;

INSERT INTO westminster_parliamentary_constituency
SELECT code, name FROM read_parquet(getenv('NSUL_LOOKUPS_DIR') || '/westminster_parliamentary_constituency.parquet')
ON CONFLICT (code) DO NOTHING;

INSERT INTO ward
SELECT code, name FROM read_parquet(getenv('NSUL_LOOKUPS_DIR') || '/ward.parquet')
ON CONFLICT (code) DO NOTHING;

INSERT INTO health_area
SELECT code, name FROM read_parquet(getenv('NSUL_LOOKUPS_DIR') || '/health_area.parquet');

INSERT INTO european_electoral_region
SELECT code, name FROM read_parquet(getenv('NSUL_LOOKUPS_DIR') || '/european_electoral_region.parquet');

INSERT INTO travel_to_work_area
SELECT code, name FROM read_parquet(getenv('NSUL_LOOKUPS_DIR') || '/travel_to_work_area.parquet');

INSERT INTO international_territorial_level
SELECT code, name FROM read_parquet(getenv('NSUL_LOOKUPS_DIR') || '/international_territorial_level.parquet');

INSERT INTO national_park
SELECT code, name FROM read_parquet(getenv('NSUL_LOOKUPS_DIR') || '/national_park.parquet');

INSERT INTO lower_super_output_area_21
SELECT code, name FROM read_parquet(getenv('NSUL_LOOKUPS_DIR') || '/lower_super_output_area_21.parquet');

INSERT INTO middle_super_output_area_21
SELECT code, name FROM read_parquet(getenv('NSUL_LOOKUPS_DIR') || '/middle_super_output_area_21.parquet');

INSERT INTO sub_integrated_care_board
SELECT code, name FROM read_parquet(getenv('NSUL_LOOKUPS_DIR') || '/sub_integrated_care_board.parquet');

INSERT INTO rural_urban_21_indicator
SELECT code, name FROM read_parquet(getenv('NSUL_LOOKUPS_DIR') || '/rural_urban_21_indicator.parquet');

INSERT INTO output_area_classification_21
SELECT code, name, group_name, supergroup_name
FROM read_parquet(getenv('NSUL_LOOKUPS_DIR') || '/output_area_classification_21.parquet');

INSERT INTO local_enterprise_partnership
SELECT code, name FROM read_parquet(getenv('NSUL_LOOKUPS_DIR') || '/local_enterprise_partnership.parquet');

INSERT INTO police_force_area
SELECT code, name FROM read_parquet(getenv('NSUL_LOOKUPS_DIR') || '/police_force_area.parquet');