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
FROM postcodes p
LEFT JOIN built_up_area b ON p.built_up_area_24_code = b.code
LEFT JOIN country c ON p.country_code = c.code
LEFT JOIN county co ON p.county_code = co.code
LEFT JOIN county_electoral_division ced ON p.county_electoral_division_code = ced.code
LEFT JOIN local_authority_district lad ON p.local_authority_district_code = lad.code
LEFT JOIN region r ON p.region_code = r.code
LEFT JOIN rural_urban_11_indicator ru ON p.rural_urban_11_code = ru.indicator
LEFT JOIN westminster_parliamentary_constituency wpc ON p.westminster_parliamentary_constituency_code = wpc.code
LEFT JOIN ward w ON p.ward_code = w.code;