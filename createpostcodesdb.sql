INSTALL spatial;
LOAD spatial;

CREATE TABLE postcode (
    postcode VARCHAR PRIMARY KEY,
    date_of_termination VARCHAR,
    county_code VARCHAR,
    county_electoral_division_code VARCHAR,
    local_authority_district_code VARCHAR,
    ward_code VARCHAR,
    easting INTEGER,
    northing INTEGER,
    country_code VARCHAR,
    region_code VARCHAR,
    westminster_parliamentary_constituency_code VARCHAR,
    output_area_11_code VARCHAR,
    lower_super_output_area_11_code VARCHAR,
    middle_super_output_area_11_code VARCHAR,
    built_up_area_24_code VARCHAR,
    rural_urban_11_code VARCHAR,
    index_multiple_deprivation_rank INTEGER,
    output_area_21_code VARCHAR,
    lower_super_output_area_21_code VARCHAR,
    middle_super_output_area_21_code VARCHAR,
    longitude DOUBLE,
    latitude DOUBLE
);

-- Load the data from the parquet file into the postcodes table
-- pcds,doterm,cty25cd,ced25cd,lad25cd,wd25cd,east1m,north1m,ctry25cd,rgn25cd,pcon24cd,oa11cd,lsoa11cd,msoa11cd,bua24cd,ruc11ind,imd20ind,oa21cd,lsoa21cd,msoa21cd,lat,long
INSERT INTO postcode
SELECT replace(pcds, ' '::VARCHAR, ''::VARCHAR) as postcode,
       doterm as date_of_termination,
       cty25cd as county_code,
       ced25cd as county_electoral_division_code,
       lad25cd as local_authority_district_code,
       wd25cd as ward_code,
       east1m as easting,
       north1m as northing,
       ctry25cd as country_code,
       rgn25cd as region_code,
       pcon24cd as westminster_parliamentary_constituency_code,
       oa11cd as output_area_11_code,
       lsoa11cd as lower_super_output_area_11_code,
       msoa11cd as middle_super_output_area_11_code,
       bua24cd as built_up_area_24_code,
       ruc11ind as rural_urban_11_code,
       imd20ind as index_multiple_deprivation_rank,
       oa21cd as output_area_21_code,
       lsoa21cd as lower_super_output_area_21_code,
       msoa21cd as middle_super_output_area_21_code,
       long as longitude,
       lat as latitude
FROM read_parquet('data/ons-postcode-directory.parquet');

-- On the postcodes table create a geometry column from longitude and latitude using st_point
ALTER TABLE postcode ADD COLUMN geometry geometry;
UPDATE postcode SET geometry = st_point(longitude, latitude);

-- Create a duckdb spatial index
CREATE INDEX postcode_geom_idx ON postcode USING RTREE (geometry);

-- create a table for the BUA24 areas
CREATE TABLE built_up_area (
    code VARCHAR,
    name VARCHAR
);

-- Load the data from the parquet file into the bua24 table
INSERT INTO built_up_area
SELECT BUA24CD as code, BUA24NM as name
FROM read_parquet('data/bua24-codes.parquet');

-- create a table for the countries
CREATE TABLE country (
    code VARCHAR PRIMARY KEY,
    name VARCHAR
);

-- Load the data from the parquet file into the countries table
INSERT INTO country
SELECT CTRY25CD as code, CTRY25NM as name
FROM read_parquet('data/country-codes.parquet')
WHERE CTRY25CD IS NOT NULL;

-- create a table for the counties
CREATE TABLE county (
    code VARCHAR PRIMARY KEY,
    name VARCHAR
);

-- Load the data from the parquet file into the counties table
INSERT INTO county
SELECT CTY25CD as code, CTY25NM as name
FROM read_parquet('data/county-codes.parquet')
WHERE CTY25CD IS NOT NULL;


-- create a table for the county electoral divisions
CREATE TABLE county_electoral_division (
    code VARCHAR PRIMARY KEY,
    name VARCHAR
);

-- Load the data from the parquet file into the county_electoral_divisions table
INSERT INTO county_electoral_division
SELECT CED25CD as code, CED25NM as name
FROM read_parquet('data/ced-codes.parquet')
WHERE CED25CD IS NOT NULL;

-- create a table for the local authority districts
CREATE TABLE local_authority_district (
    code VARCHAR PRIMARY KEY,
    name VARCHAR
);

-- Load the data from the parquet file into the local_authority_districts table
INSERT INTO local_authority_district
SELECT LAD25CD as code, LAD25NM as name
FROM read_parquet('data/la-ua-codes.parquet')
WHERE LAD25CD IS NOT NULL;


-- create a table for the regions
CREATE TABLE region (
    code VARCHAR PRIMARY KEY,
    name VARCHAR
);

-- Load the data from the parquet file into the regions table
INSERT INTO region
SELECT RGN25CD as code, RGN25NM as name
FROM read_parquet('data/region-codes.parquet')
WHERE RGN25CD IS NOT NULL;


-- create a table for the Rural Urban (2011) Indicators
CREATE TABLE rural_urban_11_indicator (
    indicator VARCHAR PRIMARY KEY,
    name VARCHAR
);

-- Load the data from the parquet file into the rural_urban_11_indicators table
INSERT INTO rural_urban_11_indicator
SELECT RU11IND as indicator, RU11NM as name
FROM read_parquet('data/ru11-codes.parquet');


-- create a table for the Westminster Parliamentary Constituencies
CREATE TABLE westminster_parliamentary_constituency (
    code VARCHAR PRIMARY KEY,
    name VARCHAR
);

-- Load the data from the parquet file into the westminster_parliamentary_constituencies table
INSERT INTO westminster_parliamentary_constituency
SELECT PCON24CD as code, PCON24NM as name
FROM read_parquet('data/pcon-codes.parquet');


-- create a table for the wards
CREATE TABLE ward (
    code VARCHAR PRIMARY KEY,
    name VARCHAR
);

-- Load the data from the parquet file into the wards table
INSERT INTO ward
SELECT WD25CD as code, WD25NM as name
FROM read_parquet('data/ward-codes.parquet')
WHERE WD25CD IS NOT NULL;

CREATE VIEW vw_postcodes AS 
SELECT 
    p.postcode, 
    p.date_of_termination, 
    p.county_code,
    co.name as county_name,
    p.county_electoral_division_code,
    ced.name as county_electoral_division_name,
    p.local_authority_district_code,
    lad.name as local_authority_district_name,
    p.ward_code,
    w.name as ward_name,
    p.easting,
    p.northing,
    p.country_code,
    c.name as country_name,
    p.region_code,
    r.name as region_name,
    p.westminster_parliamentary_constituency_code,
    wpc.name as westminster_parliamentary_constituency_name,
    p.output_area_11_code,
    p.lower_super_output_area_11_code,
    p.middle_super_output_area_11_code,
    p.built_up_area_24_code,
    b.name as built_up_area_name,
    p.rural_urban_11_code,
    ru.name as rural_urban_11_name,
    p.index_multiple_deprivation_rank,
    p.output_area_21_code,
    p.lower_super_output_area_21_code,
    p.middle_super_output_area_21_code,
    p.longitude,
    p.latitude,
    p.geometry
FROM postcode p
LEFT JOIN built_up_area b ON p.built_up_area_24_code = b.code
JOIN country c ON p.country_code = c.code
JOIN county co ON p.county_code = co.code
LEFT JOIN county_electoral_division ced ON p.county_electoral_division_code = ced.code
LEFT JOIN local_authority_district lad ON p.local_authority_district_code = lad.code
JOIN region r ON p.region_code = r.code
JOIN rural_urban_11_indicator ru ON p.rural_urban_11_code = ru.indicator
JOIN westminster_parliamentary_constituency wpc ON p.westminster_parliamentary_constituency_code = wpc.code
JOIN ward w ON p.ward_code = w.code;
