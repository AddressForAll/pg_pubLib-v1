
pg_uri_root =postgres://postgres@localhost
pg_db       =test
pg_uri      =$(pg_uri_root)/$(pg_db)
PSQL ?= psql
PSQL_FLAGS ?= -X -v ON_ERROR_STOP=1

.PHONY: ini all core test test-admin test-postgis


ini:
	@echo "---- making pubLib pg_db=$(pg_db) -----"
	@echo " will change databse: $(pg_uri)"
	@echo " use make all"

all:
	@echo "... Installing functions levels 00 to 02:"
	$(PSQL) $(PSQL_FLAGS) $(pg_uri) < pubLib00-general.sql
	$(PSQL) $(PSQL_FLAGS) $(pg_uri) < pubLib01-array.sql
	$(PSQL) $(PSQL_FLAGS) $(pg_uri) < pubLib02-string.sql
	$(PSQL) $(PSQL_FLAGS) $(pg_uri) < pubLib02-bitString.sql
	$(PSQL) $(PSQL_FLAGS) $(pg_uri) < pubLib01py-string.sql
	@echo "... Installing functions level 03:"
	$(PSQL) $(PSQL_FLAGS) $(pg_uri) < pubLib03-json.sql
	$(PSQL) $(PSQL_FLAGS) $(pg_uri) < pubLib03-admin.sql
	@echo "... Installing functions level 04:"
	$(PSQL) $(PSQL_FLAGS) $(pg_uri) < pubLib04-aggregate.sql
	@echo "... Installing functions level 05:"
	$(PSQL) $(PSQL_FLAGS) $(pg_uri) < pubLib05hcode-distrib.sql
	$(PSQL) $(PSQL_FLAGS) $(pg_uri) < pubLib05hcode-encdec.sql
	$(PSQL) $(PSQL_FLAGS) $(pg_uri) < pubLib05pgis-extraSRID.sql
	$(PSQL) $(PSQL_FLAGS) $(pg_uri) < pubLib05pgis-geohash.sql
	$(PSQL) $(PSQL_FLAGS) $(pg_uri) < pubLib05xml-general.sql
	$(PSQL) $(PSQL_FLAGS) $(pg_uri) < pubLib05pgis-misc.sql
	@echo "... Installing functions level 06:"
	$(PSQL) $(PSQL_FLAGS) $(pg_uri) < pubLib06pgis-geoJSON.sql

# Core modules, without PostGIS, PL/Python, adminpack or xml2.
core:
	$(PSQL) $(PSQL_FLAGS) $(pg_uri) -f pubLib00-general.sql -f pubLib01-array.sql -f pubLib02-bitString.sql -f pubLib02-string.sql -f pubLib03-json.sql -f pubLib04-aggregate.sql -f pubLib05hcode-encdec.sql

# Run against a disposable database after installing the relevant modules.
test:
	$(PSQL) $(PSQL_FLAGS) $(pg_uri) -f asserts/v0.2.sql

test-admin:
	$(PSQL) $(PSQL_FLAGS) $(pg_uri) -f asserts/v0.2-admin.sql

test-postgis:
	$(PSQL) $(PSQL_FLAGS) $(pg_uri) -f asserts/v0.2-postgis.sql
