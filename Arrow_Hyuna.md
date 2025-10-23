# Arrow Classes I & II
## 0 Homework
### 0.1 Readings
(in no particular order)
Take a look as much as you can, but it's okay if you can't get through all
* Chapter 22 Arrow in R for Data Science: https://r4ds.hadley.nz/arrow.html
* Arrow R Package articles
  * Data objects: https://arrow.apache.org/docs/r/articles/data_objects.html
  * Reading and writing data files: https://arrow.apache.org/docs/r/articles/read_write.html
  * Data analysis with dplyr syntax: https://arrow.apache.org/docs/r/articles/data_wrangling.html
  * Working with multi-file datasets: https://arrow.apache.org/docs/r/articles/dataset.html
  * Using docker containers: https://arrow.apache.org/docs/r/articles/developers/docker.html
  * Using cloud storage: https://arrow.apache.org/docs/r/articles/fs.html
    * (Optional) Amazon S3 Userguide: https://docs.aws.amazon.com/AmazonS3/latest/userguide/Welcome.html
* Apache Arrow R Cookbook (skip Chapter 8): https://arrow.apache.org/cookbook/r/index.html

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
  # arrange(desc(TotalCheckouts)) %>%
  # head() %>%
  collect()

best_books <- best_books %>%
  group_by(CheckoutYear) %>%
  filter(TotalCheckouts == max(TotalCheckouts)) %>%
  arrange(CheckoutYear)
```
2. Which author has the most books in the Seattle library system?
```
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

ggplot(booktype, aes(x=CheckoutYear, y=TotalCheckouts,
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
  collect() %>%
  mutate(
    Creator_clean = if_else(
      str_detect(Creator, ","),
      str_trim(str_c(
        str_trim(str_extract(Creator, "(?<=,).*")),
        " ",
        str_trim(str_extract(Creator, "^[^,]+"))   
      )),
      Creator
    )
  )

clean_authors %>%
  select(Creator, Creator_clean) %>%
  distinct() %>%
  collect() %>%
  head(10)
```

### 4.3 Troubleshooting
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

## 5 ```DuckDB``` with Arrow


## 6 Docker with Arrow

## 7 S3 Cloud Storage
Not to be confused with Object-Oriented S3 in R...
