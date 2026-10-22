INSERT INTO lower_super_output_area (code, geometry)
SELECT lsoa21cd AS code, geometry
FROM read_parquet('data/prepared/lsoas.parquet');

INSERT INTO middle_super_output_area (code, geometry)
SELECT msoa21cd AS code, geometry
FROM read_parquet('data/prepared/msoas.parquet');