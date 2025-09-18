I think this works (in lieu of what is suggested in sections 4.4-4.7 of the Smith et al book)

In a shell (RStudio Terminal or a standalone terminal/shell window):

```bash
## set MYDIR to somewhere sensible on your system
## I think the only important thing is that this be a *writeable* directory
## export MYDIR=/home/bolker/Documents/classes/stat794_bigdata/sql-pet
export MYDIR=/tmp
## get/update postgres image
docker pull postgres
## clean up
docker rm --force adventureworks
## start up the container
docker run -e POSTGRES_PASSWORD="psql" --detach  --name adventureworks --publish 5432:5432 --mount type=bind,source="$MYDIR",target=/petdir postgres:11
```

## New instructions

Install docker-compose: https://docs.docker.com/compose/

``` bash
git clone https://github.com/lorint/AdventureWorks-for-Postgres.git
cd AdventureWorks-for-Postgres
## if you have wget ... otherwise download this file manually
wget https://github.com/Microsoft/sql-server-samples/releases/download/adventureworks/AdventureWorks-oltp-install-script.zip
cp AdventureWorks-oltp-install-script.zip adventure_works_2014_OLTP_script.zip
docker-compose up --build
## switch to a new shell OR ctrl-Z; bg
docker exec -i adventureworks-for-postgres_db_1 psql -U postgres -c "CREATE DATABASE Adventureworks;"
docker exec -i adventureworks-for-postgres_db_1 psql -U postgres -d Adventureworks -f install.sql
```
