CREATE VIEW vw_uprns AS
SELECT n.uprn,
	   n.postcode,
	   n.easting,
	   n.northing,
	   n.county_code,
	   co.name AS county_name,
	   n.county_electoral_division_code,
	   ced.name AS county_electoral_division_name,
	   n.local_authority_district_code,
	   lad.name AS local_authority_district_name,
	   n.ward_code,
	   w.name AS ward_name,
	   n.country_code,
	   c.name AS country_name,
	   n.region_code,
	   r.name AS region_name,
	   n.westminster_parliamentary_constituency_code,
	   pcon.name AS westminster_parliamentary_constituency_name,
	   n.output_area_21_code,
	   n.lower_super_output_area_21_code,
	   lsoa.name AS lower_super_output_area_21_name,
	   n.middle_super_output_area_21_code,
	   msoa.name AS middle_super_output_area_21_name,
	   n.built_up_area_24_code,
	   bua.name AS built_up_area_name,
	   n.rural_urban_21_indicator,
	   ruc.name AS rural_urban_21_name,
	   n.index_multiple_deprivation_rank,
	   n.health_area_code,
	   health.name AS health_area_name,
	   n.european_electoral_region_code,
	   eer.name AS european_electoral_region_name,
	   n.travel_to_work_area_code,
	   ttwa.name AS travel_to_work_area_name,
	   n.international_territorial_level_code,
	   itl.name AS international_territorial_level_name,
	   n.national_park_code,
	   npark.name AS national_park_name,
	   n.workplace_zone_11_code,
	   n.sub_integrated_care_board_code,
	   sicbl.name AS sub_integrated_care_board_name,
	   n.built_up_area_subdivision_11_code,
	   n.output_area_classification_21_indicator,
	   oac.name AS output_area_classification_21_name,
	   oac.group_name AS output_area_classification_21_group_name,
	   oac.supergroup_name AS output_area_classification_21_supergroup_name,
	   n.local_enterprise_partnership_1_code,
	   lep1.name AS local_enterprise_partnership_1_name,
	   n.local_enterprise_partnership_2_code,
	   lep2.name AS local_enterprise_partnership_2_name,
	   n.police_force_area_code,
	   pfa.name AS police_force_area_name
FROM uprns n
LEFT JOIN county co ON n.county_code = co.code
LEFT JOIN county_electoral_division ced ON n.county_electoral_division_code = ced.code
LEFT JOIN local_authority_district lad ON n.local_authority_district_code = lad.code
LEFT JOIN ward w ON n.ward_code = w.code
LEFT JOIN country c ON n.country_code = c.code
LEFT JOIN region r ON n.region_code = r.code
LEFT JOIN westminster_parliamentary_constituency pcon ON n.westminster_parliamentary_constituency_code = pcon.code
LEFT JOIN built_up_area bua ON n.built_up_area_24_code = bua.code
LEFT JOIN health_area health ON n.health_area_code = health.code
LEFT JOIN european_electoral_region eer ON n.european_electoral_region_code = eer.code
LEFT JOIN travel_to_work_area ttwa ON n.travel_to_work_area_code = ttwa.code
LEFT JOIN international_territorial_level itl ON n.international_territorial_level_code = itl.code
LEFT JOIN national_park npark ON n.national_park_code = npark.code
LEFT JOIN lower_super_output_area_21 lsoa ON n.lower_super_output_area_21_code = lsoa.code
LEFT JOIN middle_super_output_area_21 msoa ON n.middle_super_output_area_21_code = msoa.code
LEFT JOIN sub_integrated_care_board sicbl ON n.sub_integrated_care_board_code = sicbl.code
LEFT JOIN rural_urban_21_indicator ruc ON n.rural_urban_21_indicator = ruc.indicator
LEFT JOIN output_area_classification_21 oac ON upper(n.output_area_classification_21_indicator) = oac.code
LEFT JOIN local_enterprise_partnership lep1 ON n.local_enterprise_partnership_1_code = lep1.code
LEFT JOIN local_enterprise_partnership lep2 ON n.local_enterprise_partnership_2_code = lep2.code
LEFT JOIN police_force_area pfa ON n.police_force_area_code = pfa.code;