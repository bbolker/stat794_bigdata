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

Attach existing database first (not run):
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

### 7.3 SQL through ```duckplyr```

Zero-copy to ```dbplyr``` --> ```dplyr``` passthrough for SQL

Converting duckplyr frame into a dbplyr ```tbl``` object:
```
flights_tbl <- as_tbl(flights_duck)
flights_tbl
class(flights_tbl)

flights_km <- flights_tbl %>%
  select(distance, month, day) %>%
  mutate(dist_km = sql("distance * 1.60934"), 
         moxday = least_common_multiple(month, day)) %>%
  arrange(desc(dist_km)) %>%
  show_query()
  # head()

flights_km
class(flights_km)
flights_km |> as_duckdb_tibble() |> class()
```

## 8 ```data.table``` in R
R's dataframe but better

Allows you to do "related operations" (e.g., subset, group, update, join) much faster and easier

### 8.1 Introduction

#### 8.1.1 Reading in data
```
seattle_dt <- fread("Arrow/seattle-library-checkouts-tiny.csv")
class(seattle_dt)
str(seattle_dt)
head(seattle_dt$Title)

setDT() # dataframe or list
as.data.frame() # other types of objects
```

```fread()``` also supports https URLs and automatically decompresses .gz and .bz2 files (even when you're pulling them from the web).

#### 8.1.2 "Querying" Data Tables

DT[i, j, by]

R: i

SQL: where | order by

R: j

SQL: select | update  

R: by

SQL: group by

This allows R to optimize the queries before evaluating.

* Subsetting
```
# You can refer to columns like variables
seattle_dt[CheckoutYear == 2020 & MaterialType == "BOOK"] |>
  head()

# indexing still works
seattle_dt[1:3]

seattle_dt[1:3, Creator]
seattle_dt[,Creator] |> head() # vector form
seattle_dt[,list(Creator)] |> head() # data table form
seattle_dt[, c("Creator", "Checkouts")] |> head()
seattle_dt[, .(Creator, Checkouts)] |> head()
cols <- c("Creator", "Checkouts")
seattle_dt[, ..cols] |> head()

seattle_dt[, !c("Creator", "Checkouts")] |> head()
seattle_dt[, -c("Creator", "Checkouts")] |> head()

seattle_dt[, MaterialType:Checkouts]
seattle_dt[, Checkouts:MaterialType]
seattle_dt[, -(MaterialType:Checkouts)]
seattle_dt[, !(MaterialType:Checkouts)]
```

* Sorting
```
seattle_dt[order(CheckoutYear, -CheckoutMonth)] |> head()
```

* Column operations
```
# renaming (for this output only, original object is intact)
seattle_dt[, .(creator = Creator, checkouts = Checkouts)]

# computing
seattle_dt[, sum(Checkouts > 100)]
seattle_dt[CheckoutYear == 2020 & MaterialType == "BOOK",
           .(book_checkouts = sum(Checkouts), 
             median_checkouts = median(Checkouts))]
``` 

* ```.N```
: number of observations in the current group

```
seattle_dt[MaterialType == "BOOK", .N]
seattle_dt["BOOK", .N]

seattle_dt["BOOK", .N] |> system.time()
nrow(seattle_dt[MaterialType == "BOOK"]) |> system.time()
```

* Aggregations
```
seattle_dt["BOOK",.N, by = CheckoutYear]
# dropping MaterialType == because we set key earlier
seattle_dt["BOOK",.N, CheckoutYear]

seattle_dt["BOOK",.N, by = .(CheckoutYear, CheckoutMonth)]

seattle_dt["BOOK",
           .(mean_checkout = mean(Checkouts),
             monthly_checkouts = sum(Checkouts)),
           .(CheckoutYear, CheckoutMonth)][
             order(CheckoutYear, -CheckoutMonth)
           ] # chaining can go on forever

seattle_dt[, .N, .(Checkouts > 50, CheckoutYear < 2020)]
```

* ```.SD```
stands for Subset of Data

```
DT <- data.table(
  ID = c("b","b","b","a","a","c"),
  a = 1:6,
  b = 7:12,
  c = 13:18
)

DT[, print(.SD), by = ID]
DT[, lapply(.SD, mean), ID]
DT[, lapply(.SD, mean), keyby = ID] # sorted

seattle_dt["BOOK",
           lapply(.SD, sum),
           .(CheckoutYear, CheckoutMonth),
           .SDcols = "Checkouts"]
seattle_dt[, head(.SD, 2), CheckoutYear, .SDcols = "Creator"]
```

### 8.2 "By Reference"
```:=``` operation and zero-copy

Flights Dataset:
```
flights_dt <- fread("https://raw.githubusercontent.com/Rdatatable/data.table/master/vignettes/flights14.csv")
```

Adding columns:
```
flights_dt[, `:=`(speed = distance / (air_time/60), # mph
                  delay = arr_delay + dep_delay)] # min
# same as
flights_dt[, c("speed", "delay") 
        := list(distance/(air_time/60), 
                arr_delay + dep_delay)]

head(flights_dt)
```

Updating/replacing:
```
flights_dt[, sort(unique(hour))]
flights_dt[hour == 24L, hour := 0L][]
flights_dt[, sort(unique(hour))]

flights_dt[hour == 24L][, hour := 0L]
head(flights_dt)
midnight_zero <- flights_dt[hour == 24L][, hour := 0L]
nrow(midnight_zero)
flights_dt[hour == 24L, .N]
```

Deleting columns:
```
flights_dt[, c("year") := NULL] |> head()

# clean up for later
flights_dt[, c("speed", "max_speed", "max_dep_delay", "max_arr_delay") := NULL]
```

Grouping with ```:=```:
```
flights_dt[, max_speed := max(speed), by = .(origin, dest)] |> head()
```

```.SD``` like a function:
```
in_cols  = c("dep_delay", "arr_delay")
out_cols = c("max_dep_delay", "max_arr_delay")
flights_dt[, c(out_cols) := lapply(.SD, max), 
           by = month, .SDcols = in_cols]
# out_cols needs to be wrapped in () or c() because there are more than one

flights_dt[, names(.SD) := lapply(.SD, as.factor), .SDcols = is.character]
str(flights_dt)
# undo
flights_dt[, names(.SD) := lapply(.SD, as.character), .SDcols = factor_cols]
```

#### 8.2.1 ```copy()```
```:=``` makes changes to the datatable silently, which might not always be what you want.

```
monthly_speed_f <- function(DT) {
  # copy(DT)
  DT[, speed := distance / (air_time/60)] 
  DT[, .(max_speed = max(speed)), by = month]
}

monthly_speed <- monthly_speed_f(flights_dt)
monthly_speed
head(flights_dt)
# flights_dt[, speed := NULL]
```

However, ```copy()``` "deep" copies the data (i.e., copies entire data somewhere else in memory as opposed to "shallow" copying which only copies the vector of column points and not the actual data), so this may not always be best-practice.

## 8.3 Keys
: supercharged rownames

Setting a key
* reorders the rows by the column(s) in ascending order by reference
  * This is why ```keyby = ``` orders the datatable
* assigns "sorted" attribute to the key column(s)
* makes operations like searches, joins, groupings, and subsetting faster
  * Binary searches are especially fast
 
```
setkey(flights_dt, origin)
# setkeyv(seattle_dt, c("origin", "dest"))
# particularly useful while designing functions to pass columns to set key on as function arguments

seattle_dt["JFK"] # subsetting
seattle_dt["LAX"] # right join with NA values
seattle_dt[origin == "LAX"] # subsetting

setkey(flights_dt, origin, dest) # keys are ordered
flights_dt[.("JFK", "MSY")]
flights_dt[.(unique(origin), "MSY")]

flights_dt[.("LGA", "BOS"), max(arr_delay)]
```

Making changes in the key column removes its key status:
```
setkey(flights_dt, hour)
key(flights_dt)
flights_dt[.(24), hour := 0L]
key(flights_dt)
```

```keyby``` option:
```
setkey(flights_dt, origin, dest)
monthly_delay <- flights_dt["EWR", max(dep_delay), keyby = month]
key(monthly_delay)
```

### 8.3.1 Benchmarking
```
n <- 1e7L
DT <- data.table(x = sample(letters, n, replace = TRUE),
                 y = sample(1000L, n, replace = TRUE),
                 val = runif(n))

# vector scan approach
# O(n)
system.time(DT[x == "h" & y == 218L])

# binary scan approach (i.e., bisection)
# O(log n)
setkey(DT, x, y)
system.time(DT[.("h", 218L)]) 
```

### 8.3.2 ```mult``` and ```nomatch```
```
flights_dt[.("JFK", "PSP"), mult = "first"]
flights_dt[.(c("LGA", "JFK", "EWR"), "PSP"), mult = "last"]
flights_dt[.(c("LGA", "JFK", "EWR"), "PSP"), mult = "last", nomatch = NULL]
```

## 8.4 Secondary Indices
Keys are great, but sometimes you might want more than one key and/or not necessarily want the datatable reordered. And removing the keys doesn't undo the ordering.

Secondary indexing instead creates an internal attribute called "index".

```
# reset data
setindex(flights_dt, origin)
# setindexv(flights_dt, "origin")

head(flights_dt)
names(attributes(flights_dt))
indices(flights_dt)

setindex(flights_dt, dest)
indices(flights_dt)

flights_dt["MIA", on = "dest", verbose = TRUE] 
flights_dt[.("JFK", "MIA"), on = c("origin", "dest")]
flights_dt[.("JFK", "MIA"), max(arr_delay), on = c("origin", "dest")] 
flights_dt[.("JFK", "MIA"), on = c("origin", "dest")][order(-arr_delay)]

# on argument need not be an index
flights_dt[.(24L), hour := 0L, on = "hour"]
flights_dt[, sort(unique(hour))]
```

Combined with ```key, mult, nomatch```:
```
flights_dt["JFK", max(dep_delay), keyby = month, on = "origin"]
flights_dt[c("JFK", "EWR", "LGA"), on = "dest", mult = "first", nomatch = NULL]
```

#### 8.4.1 Automatic Indexing
R will automatically create an index attribute the first time you try to binary-search without an index or a key:
```
DT <- data.table(x = sample(1000L, n, replace = TRUE),
                 y = runif(n))
names(attributes(DT))

system.time(DT[x == 529])
names(attributes(DT))
indices(DT)
system.time(DT[x == 529])
system.time(DT[x %in% 520:529])

options(datatable.auto.index = FALSE)
```

## 8.5 Joins
Setting up toy datasets:
```
Products <- data.table(
  id = c(1:4,
         NA_integer_),
  name = c("banana",
           "carrots",
           "popcorn",
           "soda",
           "toothpaste"),
  price = c(0.63,
            0.89,
            2.99,
            1.49,
            2.99),
  unit = c("unit",
           "lb",
           "unit",
           "ounce",
           "unit"),
  type = c(rep("natural", 2L),
           rep("processed", 3L))
)

NewTax <- data.table(
  unit = c("unit","ounce"),
  type = "processed",
  tax_prop = c(0.65, 0.20)
)

ProductReceived <- data.table(
  id = 1:10,
  date = seq(from = as.IDate("2024-01-08"), length.out = 10L, by = "week"),
  product_id = sample(c(NA_integer_, 1:3, 6L), size = 10L, replace = TRUE),
  count = sample(c(50L, 100L, 150L), size = 10L, replace = TRUE)
)

sample_date <- function(from, to, size, ...){
  all_days = seq(from = from, to = to, by = "day")
  weekdays = all_days[wday(all_days) %in% 2:6]
  days_sample = sample(weekdays, size, ...)
  days_sample_desc = sort(days_sample)
  days_sample_desc
}

ProductSales <- data.table(
  id = 1:10,
  date = ProductReceived[, sample_date(min(date), max(date), 10L)],
  product_id = sample(c(1:3, 7L), size = 10L, replace = TRUE),
  count = sample(c(50L, 100L, 150L), size = 10L, replace = TRUE)
)

ProductPriceHistory <- data.table(
  product_id = rep(1:2, each = 3),
  date = rep(as.IDate(c("2024-01-01", "2024-02-01", "2024-03-01")), 2),
  price = c(0.59, 0.63, 0.65, 
            0.79, 0.89, 0.99)  
)
```

x[i, j, by, on, nomatch]

x: secondary datatable

i: primary datatable, list or dataframe

### 8.5.1 Equi-Join
#### 8.5.1.1 Right Join
: keeping all rows present in the table located on the right ~~(adding columns of the left-table to the rows of the right-table ??)~~

```
Products[ProductReceived, on = c(id = "product_id")]
# id from the Products table matches the product_id from the ProductReceived table

NewTax[Products, on = c("unit", "type")] # multiple columns to match

# managing names
Products[
  ProductReceived,
  on = c("id" = "product_id"),
  j = .(product_id = x.id,
        name = x.name,
        received_id = i.id,
        date = i.date,
        price,
        count,
        total_value = price * count)
]

# grouping with by =
ProductReceived[
  Products,
  on = c("product_id" = "id"),
  by = .EACHI, # grouping by each row of the right-table
  j = .(total_value_received  = sum(price * count))
]

# same as
ProductReceived[
  Products,
  on = c("product_id" = "id"),
][, .(total_value_received  = sum(price * count)),
  by = "product_id"
] # with chaining
```

If there's any name conflict, prefix ```i.``` gets added to the columns of the right-table.

Chaining is not recommended because passing to the ```j``` argument is faster and more memory-efficient.

#### 8.5.1.2 Natural Join
: joining based on common columns

```
ProductsNew <- setnames(copy(Products), "id", "product_id")
ProductsNew[ProductReceived, on = .NATURAL]
```

#### 8.5.1.3 Keyed Join
: joining based on keys of each table

Results will be sorted according to the keys.

```
ProductsK <- setkey(copy(Products), id)
ProductReceivedK <- setkey(copy(ProductReceived), product_id)

ProductsK[ProductReceivedK]
```

#### 8.5.1.4 Inner Join
: only keeping rows matched in both tables

```
Products[ProductReceived,
         on = c("id" = "product_id"),
         nomatch = NULL] # this makes it inner join
```

#### 8.5.1.5 Not join
: extract from the first table rows that do not match with any row in the second table without combining columns

```
Products[!ProductReceived, # negate second table to make it a not-join
         on = c("id" = "product_id")]
```

#### 8.5.1.6 Semi Join
: extract from the first table rows that match any row in the second table without combining columns

You need to inner-join first to get the matching row numbers, then subset:
```
# inner-join first to get row numbers
which_rows <- Products[
  ProductReceived,
  on = .(id = product_id),
  nomatch = NULL,
  which = TRUE # save the row numbers (from Products) of the matching rows
]

# subset
Products[sort(unique(which_rows))]
```

#### 8.5.1.7 Left Join
: keeping all rows present in the table located on the left

Just switch the order of the Tables...

#### 8.5.1.8 Many-to-Many Join
: joining tables based on columns with duplicate values

```
ProductReceived[product_id == 1L]
ProductSales[product_id == 1L]

ProductReceived[ProductSales[list(1L), # subsetting first
                             on = "product_id",
                             nomatch = NULL],
                on = "product_id",
                allow.cartesian = TRUE] # combining each row from one table to every row from the other 

ProductReceived[ProductSales,
                on = "product_id",
                allow.cartesian = TRUE]
```

You have to be careful since this can explode quickly when joining two large tables--- nrow(first_table)*nrow(second_table). Subset wisely:

```
ProductReceived[ProductSales[product_id == 1L],
                on = .(product_id),
                allow.cartesian = TRUE,
                mult = "first"] # or "last"
```

#### 8.5.1.9 Full Join
: combining columns without removing any row

```
merge(x = Products,
      y = ProductReceived,
      by.x = "id",
      by.y = "product_id",
      all = TRUE,
      sort = FALSE)
```

### 8.5.2 Non-Equi Join
: joins not based on exact matches but comparisons, e.g., <, >

```
ProductSales2 <- ProductSales[product_id == 2L]
ProductReceived2 <- ProductReceived[product_id == 2L]

ProductReceived2[ProductSales2,
                     on = "product_id",
                     allow.cartesian = TRUE
][date < i.date]

ProductReceived2[ProductSales2,
                     on = list(product_id, date < date), # received before sold
                     nomatch = NULL]
```

### 8.5.3 Rolling Join
: joining based on rows with the nearest matches

particularly useful for time series data

```
ProductPriceHistory[ProductSales,
                    on = .(product_id, date),
                    roll = TRUE,
                    nomatch = NULL]
```
