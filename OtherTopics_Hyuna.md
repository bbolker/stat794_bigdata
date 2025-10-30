# Other Topics 
~~since nobody told me Arrow wasn't enough to stretch for two classes~~

Continued from the Arrow class...

## 7 DuckDB Revisited: ```duckplyr```
Essentially same as ```dplyr```, but uses DuckDB in the back-end where possible to speed up computation. 

* Input and output are data frames or tibbles.
* All dplyr verbs are supported, with fallback, unlike ```dbplyr```.
* All R data types and functions are supported, with fallback.
* No SQL is generated, unlike ```dbplyr```. Instead, DuckDB’s “relational” interface is used.
* You can analyze larger-than-memory datasets from your disk or from the web.

### 7.1 DuckDB Basics
#### 7.1.1 Reading in CSV and Parquet files
```
seattle_duck_csv <- read_csv_duckdb("Arrow/seattle-library-checkouts-tiny.csv")
head(seattle_duck_csv)
class(seattle_duck_csv)

seattle_parquet <- read_parquet_duckdb("Arrow/seattle_partitioned")
head(seattle_parquet)
class(seattle_parquet)
```

#### 7.1.2 ```duckplyr``` Frames
Using NYC Flights Dataset
```
flights_df() # only 2013
class(flights_df())

flights_duck <- as_duckdb_tibble(flights_df())
class(flights_duck)

delay_df <- flights_duck %>%
  mutate(inflightdelay = arr_delay - dep_delay) |>
  # delay in minutes, negative means early departure/arrival
  group_by(year) %>%
  summarize(
    mean_inflightdelay = mean(inflightdelay, na.rm = TRUE),
    median_inflightdelay = median(inflightdelay, na.rm = TRUE),
  ) %>%
  arrange(month)
```

#### 7.1.3 Data from DuckDB

Attach existing database first:
```
library(DBI)
library(duckdb)

con <- dbConnect(duckdb(somedatabase.duckdb))
dbWriteTable(con, "data", data.frame(x = 1:3, y = letters[1:3]))

db_exec("ATTACH DATABASE 'somedatabase.duckdb' AS external (READ_ONLY)")
read_sql_duckdb("SELECT * FROM external.data")
# this is a function that runs a SQL query and returns it as a duckplyr frame
```

#### 7.1.4 Remote Data from Web
```httpfs``` extension in DuckDB allows you to analyse remote data directly in R without downloading.

```
# db_exec("INSTALL httpfs")
db_exec("LOAD httpfs")

year <- 2020:2024
base_url <- "https://blobs.duckdb.org/flight-data-partitioned/"
files <- paste0("Year=", year, "/data_0.parquet")
urls <- paste0(base_url, files)

flights <- read_parquet_duckdb(urls)
class(flights)
glimpse(flights)
flights

flights %>% count(Year) # 20 million data

delay <- flights %>%
  mutate(InFlightDelay = ArrDelay - DepDelay) |>
group_by(Year) %>%
  summarize(
    # .by = Year,
    MeanInFlightDelay = mean(InFlightDelay, na.rm = TRUE),
    MedianInFlightDelay = median(InFlightDelay, na.rm = TRUE),
  ) |>
  filter(Year < 2024) %>%
  # compute() 
  # unlike 
  collect()
  # compute_csv(path = "delay.csv")
  # compute_parquet(path = "delay.parquet")

delay
class(delay)
```

For larger-than-memory results:
* ```compute()``` materializes a lazy table in a temporary table on the database that you can use again later, but because it's temporary, it'll get deleted when you exit terminate DuckDB connection
  * vs. ```collect()``` brings data into R memory
* ```compute_csv(), compute_parquet()``` creates local CSV and Parquet files on your disk and the object is now a duckplyr frame that calls these files

#### 7.1.5 Memory Allocation for DuckDB
DuckDB takes and manages a portion of the memory space in an R session that is separate from the memory used by R objects. 

```
fallback_sitrep()
fallback_config(info = TRUE)

read_sql_duckdb("SELECT current_setting('memory_limit') AS memlimit")

# db_exec("PRAGMA memory_limit = '1GB'")
# works like DBI::dbExecute()
```

### 7.2 Troubleshooting ```duckplyr```
#### 7.2.1 Default Collection
When you use a ```dplyr``` verb that is not supported in ```duckplyr``` in a pipeline, ```duckplyr``` will automatically(!) try to pull data into memory, if possible, before running the query.

```
flights %>% group_by(Month)

flights %>% count(Year, Month) %>% group_by(Month)
```

#### 7.2.2 Prudence: Controlling Automatic Materialization

```duckplyr``` is both lazy and eager:
* For the most part, duckplyr dataframes work just like a regular data.frame()
  * Direct column access, e.g., ```$, nrow()```, works just the same
  * ```duckdb_tibble()``` will materialize requests automatically
* A duckplyr frame that is the result of a dplyr pipeline sending computation to DuckDB, it'll use lazy evaluation

This means that it is very easy to trigger an unwanted computation in a pipeline which might lead to a larger-than-memory intermediate result.

Prudence limits the size of the data that gets automatically materialized.

##### 7.2.2.1 Levels of Prudence
* lavish: always automatically materialize
  * appropriate for small to medium-sized data where DuckDB can speed things up and materialization is not a problem. Because the results are being cached after each computation, it'll make the subsequent computations faster.
  * acts like a lazy table in ```dbplyr```
* stingy: never automatically materialize, throw an error when you attempt to access data
  * can't do ```$, [], nrow(), rowwise()``` etc.
  * ```collect()``` is needed if you want to materialize
* thrifty: only automatically materialize when the data is small, otherwise throw an error
  * default 1 million cells for local files, a thousand cells for remote files

```
flights_stingy <- flights_df() %>% as_duckdb_tibble(prudence = "stingy")

# can do
# displaying data, calling column names, etc.
flights_stingy
head(names(flights_stingy))

# can't do
nrow(flights_stingy)
flights_stingy[[1]]
```

```
?read_parquet_duckdb()
# default is prudence = "thrifty"
```

Comparing object classes:
```
class(flights_stingy)

flights_stingy |>
  as_duckdb_tibble(prudence = "lavish") |>
  class()

flights_stingy |>
  collect() |>
  class()

flights_stingy |>
  as_tibble() |>
  class()

flights_stingy |>
  as.data.frame() |>
  class()
```

You can also set custom prudence:
```
read_parquet_duckdb(
  "filename.parquet",
  prudence = c(cells = 10000, rows = 1000) # you can specify cells and/or rows
)
```

#### 7.2.3 Fallback
When a command is not supported in ```duckplyr```, it'll automatically fall back to the original ```dplyr``` implementation.

```
?unsupported
```

Masking/restoring:
```
conflicted::conflict_prefer("filter", "dplyr")
```

Turning on fallback warnings (Default is silent):
```
Sys.setenv(DUCKPLYR_FALLBACK_INFO = TRUE)
destinations <- flights_df() |>
  summarize(.by = origin, destinations = paste(dest, collapse = " "))
```

```dplyr``` accesses columns directly, which means it'll try to materialize the frames before running the commands.

```
flights_stingy |>
  group_by(origin) |>
  summarize(n = n()) 

flights_df() %>% as_duckdb_tibble(prudence = "thrifty") |>
  group_by(origin) |>
  summarize(n = n()) 

flights_df() %>% as_duckdb_tibble(prudence = "lavish") |>
  group_by(origin) |>
  summarize(n = n()) 
```

#### 7.2.4 Things to Be Careful About
Known Incompatibilities between ```duckplyr``` and ```dplyr```

##### 7.2.4.1 Output Order Stability
DuckDB (and therefore ```duckplyr```) does not guarantee order stability for the output.

```
flights_duck %>% distinct(day) %>%
  summarise(paste(day, collapse = " "))
```

You can set in environment ```DUCKPLYR_OUTPUT_ORDER = "TRUE"``` to fix this:
```
withr::with_envvar(
  c(DUCKPLYR_OUTPUT_ORDER = "TRUE"),
  flights_duck %>% distinct(day) %>%
    summarise(paste(day, collapse = " "))
  )
```

cf.
```
?config

Sys.setenv(DUCKPLYR_FORCE = FALSE)
```

##### 7.2.4.2 Empty Objects

Zero-column tibbles are not supported:

```
# as input
x <- duckdb_tibble()

# as output
duckdb_tibble(a = 1) |>
  select(-a)
```

Empty vectors in aggregate functions also work differently in ```duckplyr``` than in ```dplyr```:

```
duckdb_tibble(a = integer(), b = logical()) |>
  summarize(sum(a), any(b), all(b), min(a), max(a))

detach("package:duckplyr", unload = TRUE)
tibble(a = integer(), b = logical()) |>
  summarize(sum(a), any(b), all(b), min(a), max(a))
```

##### 7.2.4.3 Logical Inputs
```
duckdb_tibble(a = c(TRUE, FALSE)) |>
  summarize(min(a), max(a))

detach("package:duckplyr", unload = TRUE)
tibble(a = c(TRUE, FALSE)) |>
  summarize(min(a), max(a))
```

##### 7.2.4.4 ```NA, NaN```
```dplyr``` treats ```NA``` and ```NaN``` both like null values--- ```duckplyr``` doesn't.

```
duckdb_tibble(a = c(NA, NaN)) |>
  mutate(is.na(a))

detach("package:duckplyr", unload = TRUE)
tibble(a = c(NA, NaN)) |>
  mutate(is.na(a))
```

#### 7.2.5 Custom Functions

```duckplyr``` can't handle custom functions with a side effect, i.e., custom functions that spits out a return object and also interacts with an external object/program.

```
verbose_plus_one <- function(x) {
  message("Adding one to ", paste(x, collapse = ", "))
  x + 1
}

duckdb_tibble(a = 1:3) |> arrange(desc(a)) |>
  mutate(b = verbose_plus_one(a)) |>
  select(-a) %>%
  # class() %>%
  # collect() %>%
  # class()

last_rel() # only the arranging was done by duckplyr
# only when we collect the duckdb frame, converting it to a dataframe,
# DuckDB finishes the last bit of computation left over
```

For more examples of troubleshooting ```duckplyr```, see https://duckplyr.tidyverse.org/articles/limits.html.

## 8 ```data.table``` in R

## 9 Apache Spark
