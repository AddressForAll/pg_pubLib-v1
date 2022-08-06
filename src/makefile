
pg_uri_root =postgres://postgres@localhost
pg_db       =test
pg_uri      =$(pg_uri_root)/$(pg_db)


ini:
	@echo "---- making pubLib pg_db=$(pg_db) -----"
	@echo " will change databse: $(pg_uri)"
	@echo " use make all"

all:
	@echo "... Installing functions levels 00 to 02:"
	psql $(pg_uri) < pubLib00-general.sql
	psql $(pg_uri) < pubLib01-array.sql
	psql $(pg_uri) < pubLib02-string.sql
	psql $(pg_uri) < pubLib01py-string.sql
	@echo "... Installing functions level 03:"
	psql $(pg_uri) < pubLib03-json.sql
	psql $(pg_uri) < pubLib03-admin.sql
	@echo "... Installing functions level 04:"
	psql $(pg_uri) < pubLib04-aggregate.sql
	@echo "... Installing functions level 05:"
	psql $(pg_uri) < pubLib05hcode-distrib.sql
	psql $(pg_uri) < pubLib05hcode-encdec.sql
	psql $(pg_uri) < pubLib05pgis-extraSRID.sql
	psql $(pg_uri) < pubLib05pgis-geohash.sql
	psql $(pg_uri) < pubLib05xml-general.sql
	@echo "... Installing functions level 06:"
	psql $(pg_uri) < pubLib06pgis-geoJSON.sql
