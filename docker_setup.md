0. Install [Docker/Docker desktop](https://docs.docker.com/desktop/) and make sure you have a working Unix-like shell.

1. Clean up already running `adventureworks` from previous work session if needed
```{bash}
docker rm --force adventureworks
```
2. Download the files you need and put them in the right places:[^1]
```{bash}
git clone https://github.com/lorint/AdventureWorks-for-Postgres.git
## OR download zip file and unzip (see below)
cd AdventureWorks-for-Postgres
wget https://github.com/Microsoft/sql-server-samples/releases/download/adventureworks/AdventureWorks-oltp-install-script.zip
mv AdventureWorks-oltp-install-script.zip adventure_works_2014_OLTP_script.zip
```

[^1:] `wget` is a common command-line tool (but separate from the standard Unix shell tools): you can get it for Windows from [here](https://gnuwin32.sourceforge.net/packages/wget.htm); on MacOS, you can [install it via Homebrew](https://formulae.brew.sh/formula/wget).

You can download the repository manually rather than via `git`, from [here](https://github.com/lorint/AdventureWorks-for-Postgres/archive/refs/heads/master.zip). If you do it that way, you have to unzip manually:

```{bash}
unzip <zip_file_name>
mv AdventureWorks-for-Postgres-master AdventureWorks-for-Postgres
```

AdventureWorks-for-Postgres

3. Build docker image:

```{bash}
cd .. ## go back up one level
docker build -t mypsql AdventureWorks-for-Postgres/
```

3. Start docker container

```{bash}
docker run -e POSTGRES_PASSWORD="postgres" --detach  --name adventureworks --publish 5432:5432 --mount type=bind,source=.,target=/petdir mypsql
```

4. Create and populate database inside the container

```{bash}
docker exec adventureworks psql -U postgres -c "CREATE DATABASE Adventureworks;"  
docker exec adventureworks psql -U postgres -d Adventureworks -f install.sql
```

## exploring/troubleshooting

* `docker images`: list available/downloaded images
* `docker ps`: list running containers
* `docker rm --force <container>`: remove container 
* `docker rmi <image>`: remove image
* `docker exec -it <container> bash`: open a shell inside a running container
* `exit`/Ctrl-D: quit a running shell 
