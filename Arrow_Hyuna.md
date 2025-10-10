# Arrow Classes I & II
## Homework
### Readings
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

### Files/Software
* Install Arrow R Package
* Install NYC Taxi and Seattle Library datasets (sorry...)
```
install.packages("arrow")
curl::multi_download(
  "https://r4ds.s3.us-west-2.amazonaws.com/seattle-library-checkouts.csv",
  "directory/your_file_name",
  resume = TRUE
)

```

## 1. Introduction & Data Types
### 1.1 What Is Arrow

* language-agnostic tool
* in-memory columnar format: represents structured, table-like data
* for efficient analysis and transport of large datasets
* is available through the ``` arrow ``` package in R
* ```dplyr``` backend
* is very fast!
* Usually paired with Parquet-formatted data
  * Parquet: column-oriented data format, provides efficient storage, retrieval, compression, and encoding for complex data in bulk

### 1.1 Data Objects & How to Read Them


```
code
```

- [ ] checklist
- [x] finish checklist
