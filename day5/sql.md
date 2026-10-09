docker compose up -d
docker compose ps
docker exec -it pg-primary psql -U admin -d appdb -c "SELECT version();"

docker exec -it pg-primary psql -U admin -d appdb

CREATE TABLE orders (
  id SERIAL PRIMARY KEY,
  customer TEXT NOT NULL,
  amount NUMERIC(10,2) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO orders (customer, amount)
SELECT 'customer_' || (random()*1000)::int, (random()*500)::numeric(10,2)
FROM generate_series(1, 100000);

SELECT count(*) FROM orders;


###########################
Least Privelege Role
###########################
CREATE ROLE app_rw LOGIN PASSWORD 'AppRw#2026';
CREATE ROLE app_ro LOGIN PASSWORD 'AppRo#2026';
CREATE ROLE replicator REPLICATION LOGIN PASSWORD 'Repl#2026';

GRANT CONNECT ON DATABASE appdb TO app_rw, app_ro;
GRANT USAGE ON SCHEMA public TO app_rw, app_ro;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_rw;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO app_rw;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO app_ro;


###############################
Test permission
##################################
docker exec -it pg-primary psql -U app_ro -d appdb -c "DELETE FROM orders;"

################################
Backup 
################################
docker exec pg-primary pg_dump -U admin -Fc appdb > backups/appdb_$(date +%F).dump
ls -lh backups/

###########################
simulate disaster
##########################
docker exec -it pg-primary psql -U admin -d appdb -c "DROP TABLE orders;"

############################
Restore
############################
cat backups/appdb_$(date +%F).dump | docker exec -i pg-primary pg_restore -U admin -d appdb --clean --if-exists
docker exec -it pg-primary psql -U admin -d appdb -c "SELECT count(*) FROM orders;"

