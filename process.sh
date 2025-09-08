#!/bin/bash

# Unzip and then rename the postcode file
unzip data/ons-postcode-directory.zip "Data/ONSPD_*.csv"
mv data/ONSPD_*.csv data/ons-postcode-directory.csv

# Unzip the BUA24 names and codes
unzip data/ons-postcode-directory.zip "Documents/BUA Built Up Area names and codes*.csv"
mv Documents/BUA\ Built\ Up\ Area\ names\ and\ codes*.csv data/bua24-codes.csv

# Unzip the Country codes lookup file
unzip data/ons-postcode-directory.zip "Documents/CTRY Country names and codes *.csv"
mv Documents/CTRY\ Country\ names\ and\ codes*.csv data/country-codes.csv

# Unzip the County names and codes
unzip data/ons-postcode-directory.zip "Documents/CTY County names and codes*.csv"
mv Documents/CTY\ County\ names\ and\ codes*.csv data/county-codes.csv

# Unzip the County Electoral Division names and codes
unzip data/ons-postcode-directory.zip "Documents/CED County Electoral Division names and codes*.csv"
mv Documents/CED\ County\ Electoral\ Division\ names\ and\ codes*.csv data/ced-codes.csv

# Unzip the LA_UA names and codes
unzip data/ons-postcode-directory.zip "Documents/LAD Local Authority District names and codes*.csv"
mv Documents/LAD\ Local\ Authority\ District\ names\ and\ codes*.csv data/la-ua-codes.csv

# Unzip the Region names and codes
unzip data/ons-postcode-directory.zip "Documents/RGN Region names and codes *.csv"
mv Documents/RGN\ Region\ names\ and\ codes*.csv data/region-codes.csv

# Unzip the Rural Urban (2011) Indicator names and codes
unzip data/ons-postcode-directory.zip "Documents/RUC11 Rural Urban (2011) Indicator names and codes*.csv"
mv Documents/RUC11\ Rural\ Urban\ \(2011\)\ Indicator\ names\ and\ codes*.csv data/ru11-codes.csv

# Unzip the Ward names and codes UK as at 05_21.csv
unzip data/ons-postcode-directory.zip "Documents/WD Ward names and codes*.csv"
mv Documents/WD\ Ward\ names\ and\ codes*.csv data/ward-codes.csv

# Unzip the Westminster Parliamentary Constituency names and codes UK as at 05_23.csv
unzip data/ons-postcode-directory.zip "Documents/PCON Westminster Parliamentary Constituency names and codes*.csv"
mv Documents/PCON\ Westminster\ Parliamentary\ Constituency\ names\ and\ codes*.csv data/pcon-codes.csv

# Filter the MSOA boundary data to only include the msoa21cd field
ogr2ogr -f GeoJSON -select "msoa21cd" data/msoas-filtered.geojson data/msoas.geojson

# Filter the LSOA boundary data to only include the lsoa21cd field
ogr2ogr -f GeoJSON -select "lsoa21cd" data/lsoas-filtered.geojson data/lsoas.geojson

# Filter the ONS postcode directory to only include the fields we will be using
ogr2ogr -f CSV -select "pcds,doterm,cty25cd,ced25cd,lad25cd,wd25cd,east1m,north1m,ctry25cd,rgn25cd,pcon24cd,oa11cd,lsoa11cd,msoa11cd,bua24cd,ruc11ind,imd20ind,oa21cd,lsoa21cd,msoa21cd,lat,long" data/ons-postcode-directory-filtered.csv data/ons-postcode-directory.csv

# Filter the BUA24 codes lookup to only include the fields we will be using
ogr2ogr -f CSV -select "BUA24CD,BUA24NM" data/bua24-codes-filtered.csv data/bua24-codes.csv

# Filter the Country codes lookup to only include the fields we will be using
ogr2ogr -f CSV -select "CTRY25CD,CTRY25NM" data/country-codes-filtered.csv data/country-codes.csv

# Filter the County codes lookup to only include the fields we will be using
ogr2ogr -f CSV -select "CTY25CD,CTY25NM" data/county-codes-filtered.csv data/county-codes.csv

# Filter the County Electoral Division codes lookup to only include the fields we will be using
ogr2ogr -f CSV -select "CED25CD,CED25NM" data/ced-codes-filtered.csv data/ced-codes.csv

# Filter the LA_UA codes lookup to only include the fields we will be using
ogr2ogr -f CSV -select "LAD25CD,LAD25NM" data/la-ua-codes-filtered.csv data/la-ua-codes.csv

# Filter the Region codes lookup to only include the fields we will be using
ogr2ogr -f CSV -select "RGN25CD,RGN25NM" data/region-codes-filtered.csv data/region-codes.csv

# Filter the Rural Urban (2011) Indicator codes lookup to only include the fields we will be using
ogr2ogr -f CSV -select "RU11IND,RU11NM" data/ru11-codes-filtered.csv data/ru11-codes.csv

# Filter the Ward codes lookup to only include the fields we will be using
ogr2ogr -f CSV -select "WD25CD,WD25NM" data/ward-codes-filtered.csv data/ward-codes.csv

# Filter the Westminster Parliamentary Constituency codes lookup to only include the fields we will be using
ogr2ogr -f CSV -select "PCON24CD,PCON24NM" data/pcon-codes-filtered.csv data/pcon-codes.csv

# Convert the GeoJSON files to Geoparquet
gpq convert data/msoas-filtered.geojson data/msoas.parquet
gpq convert data/lsoas-filtered.geojson data/lsoas.parquet

# Load the ONS postcode directory to Parquet
duckdb -c "COPY(SELECT * FROM read_csv('data/ons-postcode-directory-filtered.csv', types={'ruc11ind': 'VARCHAR'})) TO 'data/ons-postcode-directory.parquet';"

# Load the BUA24 codes lookup to Parquet
duckdb -c "COPY(SELECT * FROM read_csv('data/bua24-codes-filtered.csv')) TO 'data/bua24-codes.parquet';"

# Load the country codes lookup to Parquet
duckdb -c "COPY(SELECT * FROM read_csv('data/country-codes-filtered.csv')) TO 'data/country-codes.parquet';"

# Load the County codes lookup to Parquet
duckdb -c "COPY(SELECT * FROM read_csv('data/county-codes-filtered.csv')) TO 'data/county-codes.parquet';"

# Load the County Electoral Division codes lookup to Parquet
duckdb -c "COPY(SELECT * FROM read_csv('data/ced-codes-filtered.csv')) TO 'data/ced-codes.parquet';"

# Load the LA_UA codes lookup to Parquet
duckdb -c "COPY(SELECT * FROM read_csv('data/la-ua-codes-filtered.csv')) TO 'data/la-ua-codes.parquet';"

# Load the Region codes lookup to Parquet
duckdb -c "COPY(SELECT * FROM read_csv('data/region-codes-filtered.csv')) TO 'data/region-codes.parquet';"

# Load the Rural Urban (2011) Indicator codes lookup to Parquet
duckdb -c "COPY(SELECT * FROM read_csv('data/ru11-codes-filtered.csv')) TO 'data/ru11-codes.parquet';"

# Load the Ward codes lookup to Parquet
duckdb -c "COPY(SELECT * FROM read_csv('data/ward-codes-filtered.csv')) TO 'data/ward-codes.parquet';"

# Load the Westminster Parliamentary Constituency codes lookup to Parquet
duckdb -c "COPY(SELECT * FROM read_csv('data/pcon-codes-filtered.csv')) TO 'data/pcon-codes.parquet';"