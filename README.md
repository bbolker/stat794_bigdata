Stats 744/big data
================
18 September 2025

(the `.md` version of this file is rendered from `README.Rmd`, please
edit there)

A reading course (“special topics in statistics”) at McMaster
University, Fall 2025

Basic introduction to tools

## References (in no particular order)

- “Big Book of R” section on [Data, Databases and
  Engineering](https://www.bigbookofr.com/chapters/data%20databases%20and%20engineering),
  especially [Enterprise Databases with
  R](https://smithjd.github.io/sql-pet/) (Smith et al. 2020)
- ditto, [Big Data
  section](https://www.bigbookofr.com/chapters/big%20data)
- [CRAN high-performance computing task
  view](https://cran.r-project.org/web/views/HighPerformanceComputing.html)

## Topics (in no particular order)

- command line bullshittery (Docker etc.)
- Arrow/Parquet
- SQL and substitutes (e.g. `dbplyr`); also cf `data.table`
- benchmarking
- sharding
- map-reduce
- federated algorithms
- cloud platforms and tools: Azure, Spark, etc.
- parallel computing, different models (shared vs distributed memory
  etc)

## More links (again in no particular order)

- <https://fastverse.github.io/fastverse/>
  \<<https://fastverse.github.io/fastverse/>\*
  <https://hackmd.io/@dushoff/theobioSummerLearning#containers-Docker-etc>
- Ross, Noam. 2013. “FasteR! HigheR! StrongeR! - A Guide to Speeding Up
  R Code for Busy People.” Noam Ross, April 25.
  <http://www.noamross.net/blog/2013/4/25/faster-talk.html>
  \<<http://www.noamross.net/blog/2013/4/25/faster-talk.html>.
- <https://cran.r-project.org/web/views/HighPerformanceComputing.html>
- <https://missing.csail.mit.edu/2020/data-wrangling/>
- <https://github.com/bbolker/compstatsR>

## Docker/adventureworks stuff

See the [docker adventureworks instructions](docker_setup.md)

Then in R/RStudio:

``` r
library(DBI)
con <- dbConnect(          # use in other settings
  RPostgres::Postgres(),
  # without the previous and next lines, some functions fail with bigint data 
  #   so change int64 to integer
  bigint = "integer",  
  host = "localhost",
  port = 5432,  # this version still using 5432!!!
  user = "postgres",
  password = "postgres",
  dbname = "Adventureworks"
)
print(con)
dbExecute(con, "set search_path to sales;")
dbListTables(con)
```

## junk

``` bash
docker run -e POSTGRES_PASSWORD="postgres" --detach  --name adventureworks --publish 5432:5432 --mount type=bind,source="$MYDIR",target=/petdir postgres:11
```

## References

<div id="refs" class="references csl-bib-body hanging-indent"
entry-spacing="0">

<div id="ref-smithexploring" class="csl-entry">

Smith, John David, Sophie Yang, M. Edward Borasky, Jim Tyhurst, Scott
Came, Mary Anne Thygesen, and Ian Frantz. 2020. *Exploring Enterprise
Databases with R: A Tidyverse Approach*.
<https://smithjd.github.io/sql-pet/>.

</div>

</div>
