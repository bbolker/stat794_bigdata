# Arrow & Other Topics
## 0 Homework
### 0.1 Arrow Readings
(in no particular order)
Take a look as much as you can, but it's okay if you can't get through all
* Chapter 22 Arrow in R for Data Science: https://r4ds.hadley.nz/arrow.html
* Arrow R Package articles
  * Data objects: https://arrow.apache.org/docs/r/articles/data_objects.html
  * Reading and writing data files: https://arrow.apache.org/docs/r/articles/read_write.html
  * Data analysis with dplyr syntax: https://arrow.apache.org/docs/r/articles/data_wrangling.html
  * Working with multi-file datasets: https://arrow.apache.org/docs/r/articles/dataset.html
  * Using docker containers: https://arrow.apache.org/docs/r/articles/developers/docker.html
  * ~~Using cloud storage: https://arrow.apache.org/docs/r/articles/fs.html~~
* Apache Arrow R Cookbook (skip Chapter 8): https://arrow.apache.org/cookbook/r/index.html

#### 0.1.1 Optional Readings
* ~~Amazon S3 Userguide: https://docs.aws.amazon.com/AmazonS3/latest/userguide/Welcome.html~~
* DuckDB documentation: https://duckdb.org/docs/stable/clients/r
* ```duckplyr``` documentation: https://duckplyr.tidyverse.org/
* ```data.table``` in R: https://cran.r-project.org/web/packages/data.table/vignettes/datatable-intro.html
* Apache Spark: Luraschi, J., Kuo, K., & Ruiz, E. (2020). _Mastering Spark with R : the complete guide to large-scale analysis and modeling_ (First edition.). O’Reilly Media, Inc.

### 0.2 Files/Software
* Install Arrow R Package (assuming you have dplyr, duckDB, stringr, etc.)
* Install Seattle Library dataset (sorry...)
  
```
install.packages("arrow")

# tiny Seattle dataset
options(timeout = 1800)
download.file(
  url = "https://github.com/posit-conf-2023/arrow/releases/download/v0.1.0/seattle-library-checkouts-tiny.csv",
  destfile = "your_directory/seattle-library-checkouts-tiny.csv"
)
```

## 1 Introduction & Basics

Is for larger-than-memory datasets and "lazy evaulation"

### 1.1 What Is Arrow

* language-agnostic tool
* in-memory columnar format: represents structured, table-like data
* for efficient analysis and transport of large datasets
* is available through the `arrow` package in R
* `dplyr` backend
* is very fast!

### 1.2 Data Objects

#### 1.2.1 Unique Data Objects in Arrow
* Array and chunked array: different from arrays in R, more comparable to lists and nested lists (list of lists)
* Record batch: tabular (column-wise), set of named arrays of the same length
  * creates schema for you according to the names of the arrays
  * can use `$` or `[[column_number]]` to pull specific schema like in base R
  * can use `[]` to pull rows and columns like in base R
* Table: set of named chunked arrays
  * acts like a record batch
  * can concatenate (unlike a record batch)
* Dataset: abstraction of tabular data with schema
  * not in-memory unlike record batches or tables
  * can do queries with dplyr
    * Data are only loaded into memory as needed, only when a query pulls them

```r
Array$create() # creating arrays

chunked_array() # creating chunked arrays, equivalent to:
ChunkedArray$create()

record_batch() # creating record batches, equivalent to:
RecordBatch$create()

arrow_table() # creating a table
concat_tables() # concatenating tables

open_dataset() # often used with
glimpse()
```

#### 1.2.2 Parquet
* Usually used alongside Arrow
* language-agnostic file format
* like .csv, stores tabular data but is oriented column-wise (like Arrow)
* supports efficient storage, retrieval, compression, and encoding for complex data in bulk
* supports nested/chunked data
* saves memory! 
* See also: Feather (Arrow IPC) file format

```r
read_parquet()
write_parquet()

# Parquet is also the default format in:
open_dataset()
write_dataset()
```

## 2 Reading Data & Partitioning
Load libraries:
```r
library(arrow)
library(dplyr)
```
### 2.1 Reading a Dataset
Read in the Seattle Library dataset using Arrow:
```r
# read.csv() is not recommended for a big dataset like this

seattle_csv <- open_dataset(
  sources = "Arrow/seattle-library-checkouts-tiny.csv", 
  # col_types = schema(ISBN = string()),
  # providing partial schema
  # other columns will be taken care of by arrow automatically
  format = "csv"
)

seattle_csv
glimpse(seattle_csv) # dplyr function
class(seattle_csv)
```

### 2.2 Data Engineering with Partitions
cf. `dplyr::group_by()`

#### 2.2.1 Single-Level Partitioning
```r
# dplyr
seattle_csv |> 
  group_by(CheckoutYear) |> 
  summarise(Checkouts = sum(Checkouts)) |> 
  arrange(CheckoutYear) |> 
  collect()

seattle_csv |> write_dataset(
  path = "Arrow/seattle_partitioned",
  # format = c("parquet")
  partitioning = "CheckoutYear"
  # hive_style = TRUE is default, file names as column=value
  # alternative is directory partitioning, file names just with value
  )

list.files("Arrow/seattle_partitioned")
list.files("Arrow/seattle_partitioned/CheckoutYear=2005") 
```

#### 2.2.2 Multi-Level Partitioning
```r
write_dataset(seattle_csv,
              path = "Arrow/seattle_twice_partitioned",
              partitioning = c("CheckoutYear", "MaterialType") # top to bottom in order !
              )

list.files("Arrow/seattle_twice_partitioned") 
list.files("Arrow/seattle_twice_partitioned/CheckoutYear=2005")
```

#### 2.2.3 Reading partitioned data
```r
seattle_partitioned <- open_dataset("Arrow/seattle_twice_partitioned")
seattle_partitioned
head(seattle_partitioned$files)

seattle_partitioned2 <- open_dataset(
  "Arrow/seattle_twice_partitioned",
  partitioning = c("CheckoutYear", "MaterialType"),
  hive_style = TRUE)
seattle_partitioned2

seattle_2022_BOOK <- open_dataset("Arrow/seattle_twice_partitioned/CheckoutYear=2022/MaterialType=BOOK/part-0.parquet")
seattle_2022_BOOK
```

## 3 Benchmarking
### 3.1 Comparing file sizes
Original CSV file:
```r
file.size("Arrow/seattle-library-checkouts-tiny.csv")/1e6 # in MB
```

Single Parquet file:
```r
write_dataset(seattle_csv, path = "Arrow", 
              basename_template = "seattle{i}.arrow")
file.size("Arrow/seattle0.arrow")/1e6
```

Partitioned Parquet files:
```
tibble(
  files = list.files("Arrow/seattle_partitioned", recursive = TRUE),
  MB = file.size(file.path("Arrow/seattle_partitioned", 
                           files)) / 1e6
) |> mutate(cumMB = cumsum(MB))
```

### 3.2 Comparing file formats
Using the local CSV file:
```r
seattle_readcsv <- read.csv("Arrow/seattle-library-checkouts-tiny.csv")

seattle_readcsv |> 
  filter(CheckoutYear == 2021, MaterialType == "BOOK") |>
  group_by(CheckoutMonth) |>
  summarize(TotalCheckouts = sum(Checkouts)) |>
  arrange(desc(CheckoutMonth)) |>
  collect() |> 
  system.time()
```

Using the arrow object created from the CSV file:
```r
seattle_csv |> 
  filter(CheckoutYear == 2021, MaterialType == "BOOK") |>
  group_by(CheckoutMonth) |>
  summarize(TotalCheckouts = sum(Checkouts)) |>
  arrange(desc(CheckoutMonth)) |>
  collect() |> 
  system.time()
```

Using the Parquet files:
```r
seattle_partitioned |> 
  filter(CheckoutYear == 2021, MaterialType == "BOOK") |>
  group_by(CheckoutMonth) |>
  summarize(TotalCheckouts = sum(Checkouts)) |>
  arrange(desc(CheckoutMonth)) |>
  collect() |> 
  system.time()
```

### 3.3 Comparing partitions
`filter()` in `dplyr` with partitioned variables:

```r
seattle_partitioned |>
  filter(CheckoutYear == 2019, MaterialType == "BOOK") |> 
  summarise(TotalCheckouts = sum(Checkouts)) |>
  collect() |> 
  system.time()
```

Partitioned with another variable:
```r
write_dataset(seattle_csv, 
              path = "Arrow/seattle_by_CheckoutType", 
              partitioning = "CheckoutType")

open_dataset("Arrow/seattle_by_CheckoutType") |> 
  filter(CheckoutYear == 2019, MaterialType == "BOOK") |> 
  summarise(TotalCheckouts = sum(Checkouts)) |>
  collect() |> 
  system.time()
```

## 4 `dplyr` with Arrow
### 4.1 Exercises
22.5.3 from Wickham, Centinkaya-Rundel, and Grolemund (2023)
```
schema(seattle_csv)
```

1. Figure out the most popular book each year.
```
best_books <- seattle_csv %>%
  filter(MaterialType == "BOOK", Title != "<Unknown Title>") %>%
  group_by(Title, CheckoutYear) %>%
  summarise(TotalCheckouts = sum(Checkouts)) %>%
  # ungroup() %>%
  # group_by(CheckoutYear) %>%
  # filter(TotalCheckouts == max(TotalCheckouts)) %>%
  # arrange(CheckoutYear) %>%
  # head() %>%
  collect()

best_books <- best_books %>%
  group_by(CheckoutYear) %>%
  filter(TotalCheckouts == max(TotalCheckouts)) %>%
  arrange(CheckoutYear)

class(best_books)
```
2. Which author has the most books in the Seattle library system?

```
# best author each year
best_author <- seattle_csv %>%
  filter(MaterialType == "BOOK", Creator != "") %>%
  group_by(Creator, CheckoutYear) %>%
  summarise(TotalCheckouts = sum(Checkouts)) %>%
  collect()

best_author <- best_author %>%
  group_by(CheckoutYear) %>%
  filter(TotalCheckouts == max(TotalCheckouts)) %>%
  arrange(CheckoutYear)
```

```
best_author <- seattle_csv %>%
  filter(
    MaterialType == "BOOK",
    Title != "<Unknown Title>",
    Creator != ""
  ) %>%
  group_by(Creator) %>%
  summarise(NumBooks = n_distinct(Title)) %>%
  arrange(desc(NumBooks)) %>%
  head(1) %>%
  collect()

Patterson_books <- seattle_csv %>%
  filter(
    MaterialType == "BOOK",
    Title != "<Unknown Title>",
    Creator == "Patterson, James, 1947-"
  ) %>%
  group_by(Title, PublicationYear, Publisher) %>%
  summarise(TotalCheckouts = sum(Checkouts, na.rm = TRUE)) %>%
  arrange(desc(TotalCheckouts)) %>%
  collect()
```

3. How has checkouts of books vs ebooks changed over the last 10 years?
```
seattle_csv %>%
  distinct(MaterialType) %>%
  collect()

booktype <- seattle_csv %>%
  filter(MaterialType %in% c("BOOK", "EBOOK"),
         CheckoutYear >= 2012) %>%
  group_by(CheckoutYear, MaterialType)%>%
  summarise(TotalCheckouts = sum(Checkouts)) %>%
  arrange(CheckoutYear) %>%
  collect()

library(ggplot2)
booktype_plot <- ggplot(booktype, aes(x=CheckoutYear, y=TotalCheckouts,
                     color = MaterialType)) + 
  geom_line() + geom_point() + 
  labs(title = "Checkouts of Books by Type: 2012-2022",
       x = "Year", y = "Total Checkouts", color = "Material Type") +
  scale_x_continuous(breaks = 2012:2022, labels = 2012:2022)
```

### 4.2 String Manipulation with Arrow
Author names are inconsistent (```Creator```): Some are in _First Name Last Name_ format, others are in _Last Name, First Name_ format.

Fixing:
```
library(stringr)

clean_authors <- seattle_csv %>%
  # collect() %>%
  mutate(
    Creator_clean = if_else(
      str_detect(Creator, ","),
      str_trim(str_c(
        str_trim(str_extract(Creator, "(?<=,).*")),
        # after comma: first name
        # (?<=,) positive look behind: current position immediately after comma
        # .* any number of characters
        " ", # space between first and last names
        str_trim(str_extract(Creator, "^[^,]+"))
        # start from the beginning (^) and include everything up to but excluding the first comma
        # + for however many characters
      )),
      Creator
    )
  )

# Show changes
clean_authors %>%
  select(Creator, Creator_clean) %>%
  distinct() %>%
  collect() %>%
  head(20)
```

### 4.3 Troubleshooting Arrow
#### 4.3.1 Window Functions in Arrow
A window function is a type of aggregation function that takes in $k$ inputs and spits out $k$ outputs, e.g., ```cumsum(), row_number(), rank(), lag()```, but not element-wise functions like ```round()```.

Arrow doesn't like these ):< 

Arrow doesn't like aggregate functions in general when used inside row-wise operations like ```filter()```.

```
Expression not supported in filter() in Arrow
→ Call collect() first to pull data into R.
```

#### 4.3.2 Other Functions without Arrow Mapping
Many functions from base R, ```lubridate, stringr, dplyr```, and ```tidyverse``` have Arrow mappings.

There's many without Arrow binding, however, such as ```stringr::str_detect()``` which we tried to use above.

```
Expression not supported in Arrow
→ Call collect() first to pull data into R.
```

#### 4.3.3 A Quick ~~but not great~~ Solution
One solution is to ```collect()```: Pull data into R first.

#### 4.3.4 A Better Solution
"Arrow supports zero-copy integration with DuckDB, and DuckDB can query Arrow datasets directly and stream query results back to Arrow. This integr\[a\]tion uses zero-copy streaming of data between DuckDB and Arrow and vice versa so that you can compose a query using both together, all the while not paying any cost to (re)serialize the data when you pass it back and forth. This is especially useful in cases where something is supported in one of Arrow or DuckDB query engines but not the other." - 7.5.2 Apache Arrow R Cookbook

Toss work to ```DuckDB```!

4.1 Exercise 1 revisited:

```
best_books2 <- seattle_csv %>%
  filter(MaterialType == "BOOK", Title != "<Unknown Title>") %>%
  group_by(Title, CheckoutYear) %>%
  summarise(TotalCheckouts = sum(Checkouts)) %>%
  group_by(CheckoutYear) %>%
  to_duckdb() %>%
  filter(TotalCheckouts == max(TotalCheckouts)) %>%
  arrange(CheckoutYear) %>%
  collect()

class(best_books2)
```

## 5 DuckDB with Arrow
### 5.1 Setting Up

```
library(duckdb)
```

Start an in-memory database:
```
con <- dbConnect(duckdb())
```
No changes are made in-disk and your work will be lost when you exit R/disconnect DuckDB.

If you have a local DuckDB, you can mount it:
```
con <- dbConnect(duckdb(), dbdir = "my-db.duckdb")
```

To disconnect:
```
dbDisconnect(con, shutdown = TRUE)
```

Load Arrow dataset to the database:
```
duckdb_register_arrow(con, "seattle", seattle_csv)
```

### 5.2 Working with Arrow Dataset in DuckDB
4.1 Exercises revisited:

1. Figure out the most popular book each year.
```
query1 <- "
SELECT 
  CheckoutYear,
  Title,
  SUM(Checkouts) AS TotalCheckouts
FROM seattle
WHERE MaterialType = 'BOOK' 
  AND Title <> '<Unknown Title>'
GROUP BY CheckoutYear, Title
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY CheckoutYear 
  ORDER BY SUM(Checkouts) DESC
) = 1
ORDER BY CheckoutYear
"

best_books3 <- dbGetQuery(con, query1)
```

2. Which author has the most books in the Seattle library system?
```
query2 <- "
SELECT 
  Creator,
  COUNT(DISTINCT Title) AS NumBooks
FROM seattle
WHERE MaterialType = 'BOOK'
  AND Creator IS NOT NULL
  AND TRIM(Creator) <> ''
  AND Title <> '<Unknown Title>'
GROUP BY Creator
ORDER BY NumBooks DESC
LIMIT 1
"

best_author2 <- dbGetQuery(con, query2)
```

3. How has checkouts of books vs ebooks changed over the last 10 years?
```
query3 <- "
  SELECT
    CheckoutYear,
    MaterialType,
    SUM(Checkouts) AS TotalCheckouts
  FROM seattle
  WHERE MaterialType IN ('BOOK', 'EBOOK')
    AND CheckoutYear >= 2012
  GROUP BY CheckoutYear, MaterialType
  ORDER BY CheckoutYear
"

booktype2 <- dbGetQuery(con, query3)

query4 <- "
  SELECT
    CheckoutYear,
    MaterialType,
    SUM(Checkouts) AS TotalCheckouts
  FROM seattle
  WHERE (MaterialType = 'BOOK' OR MaterialType = 'EBOOK')
    AND CheckoutYear >= 2012
  GROUP BY CheckoutYear, MaterialType
  ORDER BY CheckoutYear
"

booktype2 <- dbGetQuery(con, query4)
```

DuckDB doesn't want to do it with the Arrow dataset ):<

Solution 1: Pull from DuckDB
```
booktype2 <- dbGetQuery(con, "
  SELECT CheckoutYear, MaterialType, Checkouts
  FROM seattle
  WHERE CheckoutYear >= 2012
")

booktype2 <- booktype2 %>%
  filter(MaterialType %in% c("BOOK", "EBOOK")) %>%
  group_by(CheckoutYear, MaterialType) %>%
  summarise(TotalCheckouts = sum(Checkouts)) %>%
  arrange(CheckoutYear)

booktype_plot2 <- ggplot(booktype2, aes(x=CheckoutYear, y=TotalCheckouts,
                                      color = MaterialType)) + 
  geom_line() + geom_point() + 
  labs(title = "Checkouts of Books by Type: 2012-2022",
       x = "Year", y = "Total Checkouts", color = "Material Type") +
  scale_x_continuous(breaks = 2012:2022, labels = 2012:2022)
```

Solution 2: Abandon Arrow
```
dbExecute(con, "CREATE TABLE seattle_duck AS SELECT * FROM seattle")

booktype3 <- dbGetQuery(con, "
  SELECT CheckoutYear, MaterialType, SUM(Checkouts) AS TotalCheckouts
  FROM seattle_duck
  WHERE MaterialType IN ('BOOK','EBOOK')
    AND CheckoutYear >= 2012
  GROUP BY CheckoutYear, MaterialType
  ORDER BY CheckoutYear
")

booktype_plot3 <- ggplot(booktype3, aes(x=CheckoutYear, y=TotalCheckouts,
                                        color = MaterialType)) + 
  geom_line() + geom_point() + 
  labs(title = "Checkouts of Books by Type: 2012-2022",
       x = "Year", y = "Total Checkouts", color = "Material Type") +
  scale_x_continuous(breaks = 2012:2022, labels = 2012:2022)
```

### 5.3 Troubleshooting DuckDB

#### 5.3.1 Custom Functions

Arrow can deal with custom functions:
```
f_popular <- function(checkouts, ...) {
  out <- as.character(checkouts > 500)
}

# Register in Arrow
# works without it
register_scalar_function("popular", f_popular, 
                         in_type = int64(), out_type = string())

popular_books <- seattle_csv %>%
  filter(!is.na(Checkouts), MaterialType == "BOOK") %>%
  group_by(Title) %>%
  mutate(Popular = f_popular(Checkouts)) %>%
  filter(Popular == "true") %>%
  group_by(CheckoutYear) %>%
  arrange(desc(Checkouts)) %>%
  select(Title, CheckoutYear, Checkouts) %>%
  collect()
```

DuckDB can't deal:
```
duck_tbl <- tbl(con, "seattle")
class(duck_tbl)

duck_popular <- duck_tbl %>%
  filter(!is.na(Checkouts), MaterialType == "BOOK") %>%
  group_by(Title) %>%
  mutate(Popular = f_popular(Checkouts)) %>%
  filter(Popular == "true") %>%
  group_by(CheckoutYear) %>%
  arrange(desc(Checkouts)) %>%
  select(Title, CheckoutYear, Checkouts) %>%
  collect()
```

#### 5.3.2 Tossing Work

You can use ```to_duckdb()``` and ```to_arrow()``` to toss commands

Tossing the custom function we couldn't use to Arrow:
```
duck_popular_2arrow <- duck_tbl %>%
  filter(!is.na(Checkouts), MaterialType == "BOOK") %>%
  group_by(Title) %>%
  to_arrow() %>%
  mutate(Popular = f_popular(Checkouts)) %>%
  filter(Popular == "true") %>%
  group_by(CheckoutYear) %>%
  arrange(desc(Checkouts)) %>%
  select(Title, CheckoutYear, Checkouts) %>%
  collect()

class(duck_popular_2arrow)
```

You can also move back and forth:
```
best_popular_books <- seattle_csv %>%
  filter(MaterialType == "BOOK", Title != "<Unknown Title>") %>%
  group_by(Title, CheckoutYear) %>%
  summarise(TotalCheckouts = sum(Checkouts)) %>%
  group_by(CheckoutYear) %>%
  filter(TotalCheckouts == max(TotalCheckouts)) %>%
  mutate(Popular = f_popular(TotalCheckouts)) %>%
  filter(Popular == "true") %>%
  arrange(CheckoutYear) %>%
  collect()

best_popular_books <- seattle_csv %>%
  filter(MaterialType == "BOOK", Title != "<Unknown Title>") %>%
  group_by(Title, CheckoutYear) %>%
  summarise(TotalCheckouts = sum(Checkouts)) %>%
  group_by(CheckoutYear) %>%
  to_duckdb() %>%
  filter(TotalCheckouts == max(TotalCheckouts)) %>%
  to_arrow() %>%
  mutate(Popular = f_popular(TotalCheckouts)) %>%
  filter(Popular == "true") %>%
  arrange(CheckoutYear) %>%
  collect()

class(best_popular_books)
```

## 6 Docker with Arrow
In LINUX Ubuntu (commands might look slightly different if you're using the Terminal on Mac)

### 6.1 Setting Up

1. [Arrow has their own hub on Docker](https://hub.docker.com/r/apache/arrow-dev), where you can see the containers you can pull. I choose the latest Ubuntu container for R: "apache/arrow-dev:r-rhub-ubuntu-gcc12-latest". Pull it:

```
docker pull apache/arrow-dev:r-rhub-ubuntu-gcc12-latest
```
(This might take a few seconds)

2. Mount my directory with the data onto the container and run it:

```
$ docker run -it -e ARROW_DEPENDENCY_SOURCE=AUTO -v "$(pwd)/Arrow":/arrow apache/arrow-dev:r-rhub-ubuntu-gcc12-latest

# ls arrow
```

3. Exit Docker (turn off the container):

```
# exit
```

### 6.2 Arrow with R inside the Container
This container supports R, so you can run R commands directly while inside the container.

But weirdly it doesn't have the ```arrow``` package downloaded, so you have to install using ```install.package("arrow")```. This takes a minute, but the downloaded package gets stored in ```/tmp/RtmpDbpgYd/downloaded_packages``` inside the container. This is a temporary directory, so all gets deleted when you quit the R session unless you save the ```.RData``` file.

~~I find that it's generally slower this way but I guess that's to be expected~~

```
library(arrow)
libray(dplyr)

getwd()
setwd("arrow")
list.files(getwd())

seattle_csv <- open_dataset(sources = "seattle-library-checkouts-tiny.csv", col_types = schema(ISBN = string()), format = "csv")

schema(seattle_csv)
glimpse(seattle_csv)
```

Partitioning:

```
write_dataset(seattle_csv, path = "seattle_montly_partitioned", partitioning =
 "CheckoutMonth")
list.files("seattle_montly_partitioned")
```

Data manipulation (Exercises 1 & 3):

```
best_books <- seattle_csv %>% filter(MaterialType == "BOOK", Title != "<Unknown Title>") %>% group_by(Title, CheckoutYear) %>% summarise(TotalCheckouts = sum(Checkouts)) %>% ungroup() %>% group_by(CheckoutYear) %>% filter(TotalCheckouts == max(TotalCheckouts)) %>% arrange(CheckoutYear) %>% collect()

best_books <- seattle_csv %>% filter(MaterialType == "BOOK", Title != "<Unknown Title>") %>% group_by(Title, CheckoutYear) %>% summarise(TotalCheckouts = sum(Checkouts)) %>% collect()

best_books <- best_books %>% group_by(CheckoutYear) %>% filter(TotalCheckouts
== max(TotalCheckouts)) %>% arrange(CheckoutYear)

best_books

best_books2 <- seattle_csv %>%
  filter(MaterialType == "BOOK", Title != "<Unknown Title>") %>%
  group_by(Title, CheckoutYear) %>%
  summarise(TotalCheckouts = sum(Checkouts)) %>%
  group_by(CheckoutYear) %>%
  to_duckdb() %>%
  filter(TotalCheckouts == max(TotalCheckouts)) %>%
  arrange(CheckoutYear) %>%
  collect()

booktype <- seattle_csv %>%
  filter(MaterialType %in% c("BOOK", "EBOOK"),
         CheckoutYear >= 2012) %>%
  group_by(CheckoutYear, MaterialType)%>%
  summarise(TotalCheckouts = sum(Checkouts)) %>%
  arrange(CheckoutYear) %>%
  collect()

library(ggplot2)
booktype_plot <- ggplot(booktype, aes(x=CheckoutYear, y=TotalCheckouts,
                     color = MaterialType)) + 
  geom_line() + geom_point() + 
  labs(title = "Checkouts of Books by Type: 2012-2022",
       x = "Year", y = "Total Checkouts", color = "Material Type") +
  scale_x_continuous(breaks = 2012:2022, labels = 2012:2022)

booktype_plot

png("booktype_plot.png")
print(booktype_plot)
dev.off()
list.files()
```

Exit R and return to Docker:
```
q()
```

Copy the image file (no need for us because we've mounted our directory, which means all saved changes are on our local device as well):

```
cp arrow/booktype_plot.png ./booktype_plot.png
```

cf. See ```stevedore``` library in R.

## 7 DuckDB Revisited: ```duckplyr```
Essentially same as ```dplyr```, but uses DuckDB in the back-end where possible to speed up computation. 

You can analyze larger-than-memory datasets from your disk or from the web.

## 8 ```data.table``` in R

## 9 Apache Spark
