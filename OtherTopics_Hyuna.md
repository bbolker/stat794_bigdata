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

### 7.1 Importing Data
#### 7.1.1 Reading in CSV and Parquet files
```
seattle_duck_csv <- read_csv_duckdb("Arrow/seattle-library-checkouts-tiny.csv")
head(seattle_duck_csv)
class(seattle_duck_csv)

seattle_parquet <- read_parquet_duckdb("Arrow/seattle_partitioned")
head(seattle_parquet)
class(seattle_parquet)
```

#### 7.1.2 ```duckplyr``` Dataframe
Using NYC Flights Dataset
```
flights_df() # only 2013
class(flights_df())

flights_duck <- as_duckdb_tibble(flights_df())
class(flights_duck)

delay_df <- flights_duck %>%
  mutate(inflightdelay = arr_delay - dep_delay) |>
  # delay in minutes, negative means early departure/arrival
  # group_by(year) %>%
  summarize(
    # .by = month,
    mean_inflightdelay = mean(inflightdelay, na.rm = TRUE),
    median_inflightdelay = median(inflightdelay, na.rm = TRUE),
  ) %>%
  arrange(month)
```

#### 7.1.3 Remote Data
```httpfs``` extension in DuckDB allows you to analyse remote data directly in R without downloading.

```
db_exec("INSTALL httpfs")
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
  summarize(
    .by = Year,
    MeanInFlightDelay = mean(InFlightDelay, na.rm = TRUE),
    MedianInFlightDelay = median(InFlightDelay, na.rm = TRUE),
  ) |>
  filter(Year < 2024) 

delay
```


## 8 ```data.table``` in R

## 9 Apache Spark
