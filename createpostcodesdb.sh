rm -f ons_postcodes.duckdb

duckdb ons_postcodes.duckdb -c ".read createpostcodesdb.sql"