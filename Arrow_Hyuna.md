# Arrow Classes I & II
## 0. Homework
### 0.1 Readings
(in no particular order)
* Chapter 22 Arrow in R for Data Science: https://r4ds.hadley.nz/arrow.html
* Arrow R Package articles
  * Data objects: https://arrow.apache.org/docs/r/articles/data_objects.html
  * Reading and writing data files: https://arrow.apache.org/docs/r/articles/read_write.html
  * Data analysis with dplyr syntax: https://arrow.apache.org/docs/r/articles/data_wrangling.html
  * Working with multi-file datasets: https://arrow.apache.org/docs/r/articles/dataset.html
  * Using docker containers: https://arrow.apache.org/docs/r/articles/developers/docker.html
  * Using cloud storage: https://arrow.apache.org/docs/r/articles/fs.html
* Apache Arrow R Cookbook (skip Chapter 8): https://arrow.apache.org/cookbook/r/index.html

### 0.2 Files/Software
* Install Arrow R Package (assuming you have dplyr, duckDB, etc.)
* Install NYC Taxi and Seattle Library datasets (sorry...)
```
install.packages("arrow")

# tiny Seattle dataset
options(timeout = 1800)
download.file(
  url = "https://github.com/posit-conf-2023/arrow/releases/download/v0.1.0/seattle-library-checkouts-tiny.csv",
  destfile = "your_directory/seattle-library-checkouts-tiny.csv"
)

# tiny NYC dataset
options(timeout = 1800)
download.file(
  url = "https://github.com/posit-conf-2023/arrow/releases/download/v0.1.0/nyc-taxi-tiny.zip",
  destfile = "your_directory/nyc-taxi-tiny.zip"
)

# Extract the partitioned parquet files from the zip folder:
unzip(
  zipfile = "your_directory/nyc-taxi-tiny.zip", 
  exdir = "your_directory/"
)
```

## 1. Introduction & Basics

Is for larger-than-memory datasets and "lazy evaulation"

### 1.1 What Is Arrow

* language-agnostic tool
* in-memory columnar format: represents structured, table-like data
* for efficient analysis and transport of large datasets
* is available through the ``` arrow ``` package in R
* ```dplyr``` backend
* is very fast!

### 1.2 Data Objects

#### 1.2.1 Unique Data Objects in Arrow
* Array and chunked array: different from arrays in R, more comparable to lists and nested lists (list of lists)
* Record batch: tabular (column-wise), set of named arrays of the same length
  * creates schema for you according to the names of the arrays
  * can use ```$``` or ```[[column_number]]``` to pull specific schema like in base R
  * can use ```[]``` to pull rows and columns like in base R
* Table: set of named chunked arrays
  * acts like a record batch
  * can concatenate (unlike a record batch)
* Dataset: abstraction of tabular data with schema
  * not in-memory unlike record batches or tables
  * can do queries with dplyr
    * Data are only loaded into memory as needed, only when a query pulls them

```
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

```
read_parquet()
write_parquet()

# Parquet is also the default format in:
open_dataset()
write_dataset()
```

## 2. Reading Data & Partitioning
### 2.1 Load Libraries
```
library(arrow)
library(dplyr)
```
### 2.2 Reading a Dataset
Read in the Seattle Library dataset using Arrow:
```
# read.csv() is not recommended for a big dataset like this

seattle_csv <- open_dataset(
  sources = "Arrow/seattle-library-checkouts-tiny.csv", 
  col_types = schema(ISBN = string()),
  # other columns will be taken care of by arrow automatically
  format = "csv"
)

seattle_csv
glimpse(seattle_csv) # dplyr function
class(seattle_csv)
```

### 2.2 Partitioning
cf. ```dplyr::group_by()```

#### 2.2.1 Single-Level Partitioning
```
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
  )

list.files("Arrow/seattle_partitioned")
list.files("Arrow/seattle_partitioned/CheckoutYear=2005") 
```

#### 2.2.2 Multi-Level Partitioning
```
write_dataset(seattle_csv,
              path = "Arrow/seattle_twice_partitioned",
              partitioning = c("CheckoutYear", "MaterialType") # top to bottom in order !
              )

list.files("Arrow/seattle_twice_partitioned") 
list.files("Arrow/seattle_twice_partitioned/CheckoutYear=2005")
```

#### 2.2.3 Reading partitioned data
```
seattle_partitioned <- open_dataset("Arrow/seattle_twice_partitioned")
seattle_partitioned

seattle_partitioned2 <- open_dataset(
  "Arrow/seattle_twice_partitioned",
  partitioning = c("CheckoutYear", "MaterialType"),
  hive_style = TRUE)
seattle_partitioned2

seattle_2022_BOOK <- open_dataset("Arrow/seattle_twice_partitioned/CheckoutYear=2022/MaterialType=BOOK/part-0.parquet")
seattle_2022_BOOK
```
