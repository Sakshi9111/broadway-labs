PostgreSQL Docker Lab
1. Start PostgreSQL Containers

Start the containers in detached mode:

docker compose up -d


Check container status:

docker compose ps


Verify the PostgreSQL version:

docker exec -it pg-primary psql -U admin -d appdb -c "SELECT version();"


Connect to the database interactively:

docker exec -it pg-primary psql -U admin -d appdb

2. Create and Populate the Orders Table

Create the orders table:

CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    customer TEXT NOT NULL,
    amount NUMERIC(10,2) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);


Insert 100,000 sample records:

INSERT INTO orders (customer, amount)
SELECT
    'customer_' || (random() * 1000)::int,
    (random() * 500)::numeric(10,2)
FROM generate_series(1, 100000);


Verify the number of records:

SELECT count(*) FROM orders;


Expected result:

 count
--------
 100000

3. Create Least-Privilege Roles

Create separate roles for read-write access, read-only access, and replication.

3.1 Create Roles
CREATE ROLE app_rw LOGIN PASSWORD 'AppRw#2026';
CREATE ROLE app_ro LOGIN PASSWORD 'AppRo#2026';
CREATE ROLE replicator REPLICATION LOGIN PASSWORD 'Repl#2026';

3.2 Grant Database and Schema Permissions

Allow the application roles to connect to appdb and use the public schema:

GRANT CONNECT ON DATABASE appdb TO app_rw, app_ro;

GRANT USAGE ON SCHEMA public TO app_rw, app_ro;

3.3 Grant Read-Write Permissions

Allow app_rw to read, insert, update, and delete records:

GRANT SELECT, INSERT, UPDATE, DELETE
ON ALL TABLES IN SCHEMA public
TO app_rw;


Allow app_rw to use sequences, including those associated with SERIAL columns:

GRANT USAGE, SELECT
ON ALL SEQUENCES IN SCHEMA public
TO app_rw;

3.4 Grant Read-Only Permissions

Allow app_ro to read all existing tables in the public schema:

GRANT SELECT
ON ALL TABLES IN SCHEMA public
TO app_ro;

Note: These grants apply to existing objects. To apply equivalent permissions automatically to future tables and sequences, configure ALTER DEFAULT PRIVILEGES for the role that creates those objects.
4. Test Role Permissions

Attempt to delete records using the read-only role:

docker exec -it pg-primary \
  psql -U app_ro -d appdb \
  -c "DELETE FROM orders;"


Expected result: a permission-denied error because app_ro has only SELECT permission on the table.

5. Back Up the Database

Create a backup directory on the host if it does not already exist:

mkdir -p backups


Create a custom-format PostgreSQL backup:

docker exec pg-primary pg_dump -U admin -Fc appdb \
  > backups/appdb_$(date +%F).dump


List the available backups:

ls -lh backups/


The backup filename includes the current date, for example:

backups/appdb_2026-10-09.dump

6. Simulate a Disaster

Drop the orders table to simulate accidental data loss:

docker exec -it pg-primary \
  psql -U admin -d appdb \
  -c "DROP TABLE orders;"


Verify that the table is no longer available:

docker exec -it pg-primary \
  psql -U admin -d appdb \
  -c "SELECT count(*) FROM orders;"


This query should fail because the table has been dropped.

7. Restore the Database

Restore the database from the custom-format backup:

docker exec -i pg-primary \
  pg_restore -U admin -d appdb \
  --clean --if-exists \
  < backups/appdb_$(date +%F).dump


The command uses the backup created for the current date. If you are restoring an older backup, replace the filename with the appropriate date.

Important: The --clean --if-exists options remove existing objects covered by the backup before restoring them. Use this carefully in production.

8. Verify the Restore

Check that the orders table has been restored and contains the expected records:

docker exec -it pg-primary \
  psql -U admin -d appdb \
  -c "SELECT count(*) FROM orders;"


Expected result:

 count
--------
 100000

9. Lab Checklist
Start PostgreSQL containers.
Verify the PostgreSQL version.
Create and populate the orders table.
Create read-write, read-only, and replication roles.
Verify that the read-only role cannot delete records.
Create a database backup.
Simulate data loss by dropping the table.
Restore the database from the backup.
Verify that all 100,000 records are restored.
10. Important Security Notes
Use environment variables or a secrets manager instead of hardcoding passwords in scripts or documentation.
The sample passwords above are for lab use only.
A PostgreSQL role with the REPLICATION attribute is not automatically configured for streaming replication. Replication also requires appropriate server settings, authentication rules, and connection configuration.
For production backups, verify backup integrity and periodically test restoration in a separate environment.###


####
DevOps Responsibility
##################

### 1. DBA --> DevOps ---> 
Installation
config
role, app_specific, least privilege
Disaster recovery 