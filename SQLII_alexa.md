# SQL II

__Part A__: Chapter 11 and 12 from https://smithjd.github.io/sql-pet/chapter-leveraging-database-views.html. 

__Part B__: Chapter 5 from SQL for Data Analysis by Cathy Tanimura (avaliable online through McMaster library). 

# Part A
# Chapter 11 
* Understand database views and their uses
* Unpack a database view to see what it’s doing
* Reproduce a database view with dplyr code
* Write an alternative to a view that provides more details

## 11.1 Setup our standard working environment 

```
library(tidyverse)
library(DBI)
library(RPostgres)
library(connections)
library(glue)
re\input{SQLII_alexa.md}
quire(knitr)
library(dbplyr)
library(sqlpetr) #sp_docker_start
library(bookdown)
library(lubridate)
library(gt)
```
Connecting to `adventureworks`:
```
sleep_default <- 3
sp_check_that_docker_is_up()

sp_docker_start("adventureworks")
Sys.sleep(sleep_default)
```

```
# con <- connection_open(  # use in an interactive session
con <- dbConnect(          # use in other settings
  RPostgres::Postgres(),
  # without the previous and next lines, some functions fail with bigint data 
  #   so change int64 to integer
  bigint = "integer",  
  host = "localhost",
  port = 5432,  # this version still using 5432!!!
  user = "postgres",
  password = "psql",
  dbname = "adventureworks"
)

dbExecute(con, "set search_path to sales;") # so that `dbListFields()` works
```

## 11.2 The role of database `views`

A database `view` is an SQL query that is stored in the database. 
Most `views` are used for data retrieval, since they usually denormalize the tables involved.
*Normalization is the splitting of data into multiple related tables to reduce redundancy. 
*Denormalization is the combining of tables via joins so you don't have to query multiple tables each time.
Essentially, `views` are used to join multiple normalized tables. 

Database `views` are used for the following reasons:

1. __Authoritative__: database `views` are typically written by the business application vendor so they contain true knowledge about the structure and intended use of the database.
2. __Performance__: `views` are designed to gather data in an efficient way.
3. __Abstraction__: `views` are simplifications of complex queries that provide useful aggregations
4. __Reuse__: a `view` puts commonly used code in one place where it can be used for many purposes by many people. 
5. __Security__: a `view` can give selective access to someone who does not have access to all underlying tables or columns.
6. __Provenance__: `views` standardize data provenance. For example, the AdventureWorks database all the `views` start with a v.


## 11.3 Unpacking the elements of a `view` in the Tidyverse
A `view` is kind of like a table and so we can use similar tools in the same way we would use them on a database table. For example the easiest way of getting a list of columns in a `view` is the same way as a table:
```
dbListFields(con, "vsalespersonsalesbyfiscalyearsdata")
```

### 11.3.1 Use a `view` just like any other table
Using a view to retrieve data from the database, 
```
#this is a table
sales_order_header <- 
  tbl(con, in_schema("sales","salesorderheader")) %>% 
  collect()

str(sales_order_header)

#this is a view
v_salesperson_sales_by_fiscal_years_data <- 
  tbl(con, in_schema("sales","vsalespersonsalesbyfiscalyearsdata")) %>% 
  collect()

str(v_salesperson_sales_by_fiscal_years_data)
```

Now we just want to pull out specific columns:
```
tbl(con, in_schema("sales","vsalespersonsalesbyfiscalyearsdata")) %>% 
  count(salesterritory, fiscalyear) %>% 
  collect() %>% # ---- pull data here ---- # 
  pivot_wider(names_from = fiscalyear, values_from = n, names_prefix = "FY_")
```
Explanation:

- connecting to the view/table vsalespersonsalesbyfiscalyearsdata in the sales schema.
- count is grouping the data by salesterritory and fiscalyear.
- pivot_wider is reformatting the data from long format to wide format.
- We can now interpret the table as the number of records for each sales territory for each fiscal year. 

### 11.3.2 SQL source code
Functions for inspecting a view itself are not part of the ANSI standard, so they will be database-specific(?). Here is the code to retrieve a PostgreSQL view using `pg_get_viewdef()`:
```
view_definition <- dbGetQuery(con, "select 
                   pg_get_viewdef('sales.vsalespersonsalesbyfiscalyearsdata', 
                   true)")
                   
view_definition
```

`pg_get_viewdef()` returns a dataframe with one column and one row named pg_get_viewdef. To view it nicely we want to do the following:
```
cat(unlist(view_definition$pg_get_viewdef))
```

From this output we can interpret the SQL definition of the specified `view`. 
We want this output when we don't know what columns/joins/filters etc., a view represents. 
By using `pg_get_viewdef` we get the exact SQL query that defines the view.


Recall:
`JOIN` combines rows from multiple tables.
`ON` tells SQL how to match rows between those tables.

So for example:
```
FROM salesperson sp
JOIN salesorderheader soh ON sp.businessentityid = soh.salespersonid
```
We are taking rows from the table salesorderheader with alias soh. 
Then id's are matched from salesperson (sp) and salesorderheader (soh) where if the same ID exists in both, then SQL pairs them up.

Then interpreting a lager part of the definition:
```
FROM salesperson sp
             JOIN salesorderheader soh ON sp.businessentityid = soh.salespersonid
             JOIN salesterritory st ON sp.territoryid = st.territoryid
             JOIN humanresources.employee e ON soh.salespersonid = e.businessentityid
             JOIN person.person p ON p.businessentityid = sp.businessentityid) granula
```
We start by selecting the salesperson (sp) table. We are then making the following links:

- the salesorderheader table is joined with salesperson table where the join condition is based on the employee id, 
- the salesterritory table is joined with salesperson table where the join condition is the territory id, 
- the employee table from the humanresources schema is joined to the salesorderheader table which links the sales order's salesperson to their employee record,
- the person table from the person schema is joined to the salesperson table where the join condition is the business entity ID. 

From interpreting the SQL, this view includes the information of a salesperson including id and name, their territory and total sales.

### 11.3.3  The ERD as context for SQL code
A database Entity Relationship Diagram (ERD) is very helpful in making sense of the SQL in a view. This link did not work for me. 

### 11.3.4  Selecting relevant tables and columns
From 11.3.2, we have that the `view` vsalespersonsalesbyfiscalyearsdata joins data from five different tables:

1. sales_order_header
2. sales_territory 
3. sales_person
4. employee (from the humanresources schema)
5. person (from the person schema)

For each of the tables in the `view`, we select the columns that appear in the sales.vsalespersonsalesbyfiscalyearsdata. 
Selecting columns in this way prevents joins that `dbplyr` would make automatically based on common column names, such as `rowguid` and `ModifiedDate` columns, which appear in almost all AdventureWorks tables. 
In the following code we follow the convention that any column that we change or create on the fly uses a snake case (?) naming convention.
```
sales_order_header <- tbl(con, in_schema("sales", "salesorderheader")) %>% 
  select(orderdate, salespersonid, subtotal)

sales_territory <- tbl(con, in_schema("sales", "salesterritory")) %>% 
    select(territoryid, territory_name = name) 
  
sales_person <- tbl(con, in_schema("sales", "salesperson")) %>% 
  select(businessentityid, territoryid) 

employee <- tbl(con, in_schema("humanresources", "employee")) %>% 
  select(businessentityid, jobtitle)
```

To replicate the following code in `view`:
```
((p.firstname::text || ' '::text) ||
COALESCE(p.middlename::text || ' '::text,
''::text)) || p.lastname::text AS fullname
```

We use the following dplyr code:
```
person <- tbl(con, in_schema("person", "person")) %>% 
  mutate(full_name = paste(firstname, middlename, lastname)) %>% 
  select(businessentityid, full_name)

person
```

Double-check on the names that are defined in each `tbl` object. The following function will show the names of columns in the tables we’ve defined:
```
getnames <- function(table) {
  {table} %>% 
    collect(n = 5) %>% # ---- pull data here ---- #
    names()
}
```

Verify the names selected:
```
getnames(sales_order_header)
getnames(sales_territory)
getnames(sales_person)
getnames(employee)
getnames(person)
```

### 11.3.5 Join the tables together

We want to join this data together via `left_join`.
Recall: `left_join` keeps all observations in `x`.

```
salesperson_info <- sales_person %>% 
  left_join(employee) %>% 
  left_join(person) %>% 
  left_join(sales_territory) %>%
  collect()
  
str(salesperson_info)
```

Therefore most of the crunching(?) in this query happens on the database server side.
```
sales_data_fiscal_year <- sales_person %>% 
  left_join(sales_order_header, by = c("businessentityid" = "salespersonid")) %>% 
  group_by(businessentityid, orderdate) %>%
  summarize(sales_total = sum(subtotal, na.rm = TRUE)) %>% 
  mutate(
    orderdate = as.Date(orderdate),
    day = day(orderdate)
  ) %>%
  collect() %>% # ---- pull data here ---- #
  mutate(
    fiscal_year = year(orderdate %m+% months(6))
  ) %>% 
  ungroup() %>% 
  group_by(businessentityid, fiscal_year) %>% 
  summarize(sales_total = sum(sales_total, na.rm = FALSE)) %>% 
  ungroup()
```

Now putting `sales_data_fiscal_year` and `person_info` together to yield the final query:
```
salesperson_sales_by_fiscal_years_dplyr <- sales_data_fiscal_year %>% 
  left_join(salesperson_info) %>% 
  filter(!is.na(territoryid))
  
str(salesperson_sales_by_fiscal_years_dplyr)
```


## 11.4 Compare the official view and the dplyr output
Use `pivot_wider` to make it easier to compare the native `view` to our dplyr replicate.
```
salesperson_sales_by_fiscal_years_dplyr %>% 
  select(-jobtitle, -businessentityid, -territoryid) %>%
  pivot_wider(names_from = fiscal_year, values_from = sales_total,
              values_fill = list(sales_total = 0)) %>%
  arrange(territory_name, full_name) %>% 
  filter(territory_name == "Canada")
```

```
v_salesperson_sales_by_fiscal_years_data %>% 
  select(-jobtitle, -salespersonid) %>%
  pivot_wider(names_from = fiscalyear, values_from = salestotal,
              values_fill = list(salestotal = 0)) %>%
  arrange(salesterritory, fullname) %>% 
  filter(salesterritory == "Canada")
```
The yearly totals match exactly. The column names don’t match up, because we are using snake case convention for derived elements.



## 11.5 Revise the view to summarize by quarter not fiscal year
To summarize sales data by Sales Rep and quarter requires the `%m+%` infix operator from lubridate. 
```
tbl(con, in_schema("sales", "salesorderheader")) %>% 
  group_by(salespersonid, orderdate) %>% 
  summarize(subtotal = sum(subtotal, na.rm = TRUE), digits = 0) %>% 
  
  collect() %>% # ---- pull data here ---- #
  
  # Adding 6 months to orderdate requires a lubridate function
  mutate(orderdate = as.Date(orderdate) %m+% months(6), 
         year = year(orderdate),
         quarter = quarter(orderdate)) %>% 
  ungroup() %>%
  group_by(salespersonid, year, quarter) %>% 
  summarize(subtotal = round(sum(subtotal, na.rm = TRUE), digits = 0)) %>% 
  ungroup() %>% 
  
  # Join with the person information previously gathered
  left_join(salesperson_info, by = c("salespersonid" = "businessentityid")) %>% 
  filter(territory_name == "Canada") %>% 
  
  # Pivot to make it easier to see what's going on
  pivot_wider(names_from = quarter, values_from = subtotal,
              values_fill = list(Q1 = 0, Q2 = 0, Q3 = 0, Q4 = 0), names_prefix = "Q", id_cols = full_name:year) %>% 
  select(`Name` = full_name, year, Q1, Q2, Q3, Q4) %>%
  mutate(`Year Total` = Q1 + Q2 + Q3 + Q4) %>% 
  head(., n = 10) %>% 
  gt() %>% 
  fmt_number(use_seps = TRUE, decimals = 0, columns = vars(Q1,Q2, Q3, Q4, `Year Total`))
```

## 11.6 Clean up and close down
```
connection_close(con) # Use in an interactive setting
```

# Chapter 12 Getting metadata about and from PostgreSQL
This chapter demonstrates:

- What kind of data about the database is contained in a dbms (Database Management System).
- Several methods for obtaining metadata from the dbms.

```
library(tidyverse)
library(DBI)
library(RPostgres)
library(glue)
library(here)
require(knitr)
library(dbplyr)
library(sqlpetr)
```

```
sp_docker_start("adventureworks")
```

```
# con <- sqlpetr::sp_get_postgres_connection(
#   user = Sys.getenv("DEFAULT_POSTGRES_USER_NAME"),
#   password = Sys.getenv("DEFAULT_POSTGRES_PASSWORD"),
#   dbname = "adventureworks",
#   port = 5432, 
#   seconds_to_test = 20, 
#   connection_tab = TRUE
# )

con <- sqlpetr::sp_get_postgres_connection(
  user = "postgres",
  password = "psql",
  dbname = "adventureworks",
  port = 5432
)
```

## 12.1 Views trick parked here for the time being
### 12.1.1 Explore the vsalelsperson and vsalespersonsalesbyfiscalyearsdata views
```
cat(unlist(dbGetQuery(con, "select pg_get_viewdef('sales.vsalesperson', true)")))
```

## 12.2 Database contents and structure
After just looking at the data you seek, it might be worthwhile stepping back and looking at the big picture.

### 12.2.1 Database structure
For large or complex databases you need to use both the available documentation for your database and the other empirical tools that are available like the Entity Relationship Diagram (ERD) in Chapter 11.

### 12.2.2 Contents of the information_schema
For this chapter R needs the `dbplyr` package to access alternate schemas where a schema is an object that contains one or more tables.

### 12.2.3 What tables are in the database?

The simplest way to get a list of tables is with (NO LONGER WORKS):
```
schema_list <- tbl(con, in_schema("information_schema", "schemata")) %>%
  select(catalog_name, schema_name, schema_owner) %>%
  collect()

sp_print_df(head(schema_list))
```

We usually need more detail than just a list of tables. Most SQL databases have an `information_schema` that has a standard structure to describe and control the database.

The `information_schema` is in a different schema from the default, so to connect to the tables table in the `information_schema` we connect to the database in a different way:
```
table_info_schema_table <- tbl(con, dbplyr::in_schema("information_schema", "tables"))
```

The `information_schema` contains 343 tables. 
This query retrieves a list of the tables in the database that includes additional detail:
```
table_info <- table_info_schema_table %>%
  # filter(table_schema == "public") %>%
  select(table_catalog, table_schema, table_name, table_type) %>%
  arrange(table_type, table_name) %>%
  collect()

sp_print_df(head(table_info))
sp_print_df(table_info)
```

The following SQL query returns the same information as the previous dplyr code.
Note `rs` is shorthand for result set. 
```
rs <- dbGetQuery(
  con,
  "select table_catalog, table_schema, table_name, table_type 
  from information_schema.tables 
  where table_schema not in ('pg_catalog','information_schema')
  order by table_type, table_name 
  ;"
)
sp_print_df(head(rs))
```

## 12.3 What columns do those tables contain?
The DBI package has a `dbListFields` function that provides the simplest way to get a list of column names, but the `information_schema` has a lot more useful information that we can use.
```
#dbExecute(con, "set search_path to sales;") # so that `dbListFields()` works
#DBI::dbListFields(con, sales)
```


```
columns_info_schema_table <- tbl(con, dbplyr::in_schema("information_schema", "columns"))
```
The information_schema contains 3,297 columns.
```
columns_info_schema_info <- columns_info_schema_table %>%
  # filter(table_schema == "public") %>%
  select(
    table_catalog, table_schema, table_name, column_name, data_type, ordinal_position,
    character_maximum_length, column_default, numeric_precision, numeric_precision_radix
  ) %>%
  collect(n = Inf) %>%
  mutate(data_type = case_when(
    data_type == "character varying" ~ paste0(data_type, " (", character_maximum_length, ")"),
    data_type == "real" ~ paste0(data_type, " (", numeric_precision, ",", numeric_precision_radix, ")"),
    TRUE ~ data_type
  )) %>%
  # filter(table_name == "rental") %>%
  select(-table_schema, -numeric_precision, -numeric_precision_radix)

glimpse(columns_info_schema_info)

sp_print_df(head(columns_info_schema_info))
```

### 12.3.1 What is the difference between a VIEW and a BASE TABLE?
The BASE TABLE has the underlying data in the database.
```
table_info_schema_table %>%
  filter( table_type == "BASE TABLE") %>%
  # filter(table_schema == "public" & table_type == "BASE TABLE") %>%
  select(table_name, table_type) %>%
  left_join(columns_info_schema_table, by = c("table_name" = "table_name")) %>%
  select(
    table_type, table_name, column_name, data_type, ordinal_position,
    column_default
  ) %>%
  collect(n = Inf) %>%
  filter(str_detect(table_name, "cust")) %>%
  head() %>% 
  sp_print_df()
```

Probably should explore how the VIEW is made up of data from BASE TABLEs.
```
table_info_schema_table %>%
  filter( table_type == "VIEW") %>%
  # filter(table_schema == "public" & table_type == "VIEW") %>%
  select(table_name, table_type) %>%
  left_join(columns_info_schema_table, by = c("table_name" = "table_name")) %>%
  select(
    table_type, table_name, column_name, data_type, ordinal_position,
    column_default
  ) %>%
  collect(n = Inf) %>%
  filter(str_detect(table_name, "cust")) %>%
  head() %>% 
  sp_print_df()
```

### 12.3.2 What data types are found in the database?
```
columns_info_schema_info %>% 
  count(data_type) %>% 
  head() %>% 
  sp_print_df()
```

## 12.4 Characterizing how things are named
Names are the handle for accessing the data. 
Tables and columns may or may not be named consistently or in a way that makes sense to you. You should look at these names as data.

### 12.4.1 Counting columns and name reuse
Pull out some statistics about your database. 
Since we are in SQL-land we talk about variables as columns.
```
public_tables <- columns_info_schema_table %>%
  # filter(str_detect(table_name, "pg_") == FALSE) %>%
  # filter(table_schema == "public") %>%
  collect()

public_tables %>%
  count(table_name, sort = TRUE) %>% 
  head(n = 15) %>% 
  sp_print_df()
```

How many column names are shared across tables (or duplicated)? 
We are finding common column names and sorting them based on how many times they occur.
```
public_tables %>% count(column_name, sort = TRUE) %>% 
  filter(n > 1) %>% 
  head()
```

Finding the number of unique column names? (In the textbook it says 882, I have 1029.)
```
public_tables %>% 
  count(column_name) %>% 
  filter(n == 1) %>% 
  count() %>% 
  head()
```

## 12.5 Database keys
Database keys are values used in relational databases to identify rows within a table, giving each row a unique id, and establishing relationships between different tables.

### 12.5.1 Direct SQL
How do we use this output? Could it be generated by dplyr?
```
rs <- dbGetQuery(
  con,
  "
--SELECT conrelid::regclass as table_from
select table_catalog||'.'||table_schema||'.'||table_name table_name
, conname, pg_catalog.pg_get_constraintdef(r.oid, true) as condef
FROM information_schema.columns c,pg_catalog.pg_constraint r
WHERE 1 = 1 --r.conrelid = '16485' 
  AND r.contype  in ('f','p') ORDER BY 1
;"
)
glimpse(rs)
```
(Textbook says ## Observations: 467,838, we have Rows: 725,340.)

```
sp_print_df(head(rs))
```

Textbook says "The following is more compact and looks more useful." But it doesn't work for me.
```
rs <- dbGetQuery(
  con,
  "select conrelid::regclass as table_from
      ,c.conname
      ,pg_get_constraintdef(c.oid)
  from pg_constraint c
  join pg_namespace n on n.oid = c.connamespace
 where c.contype in ('f','p')
   and n.nspname = 'public'
order by conrelid::regclass::text, contype DESC;
"
)
glimpse(rs)
```

```
sp_print_df(head(rs))
dim(rs)[1]
```

## 12.5.2 Database keys with dplyr
This query shows the primary and foreign keys in the database. (This does work.)
```
tables <- tbl(con, dbplyr::in_schema("information_schema", "tables"))
table_constraints <- tbl(con, dbplyr::in_schema("information_schema", "table_constraints"))
key_column_usage <- tbl(con, dbplyr::in_schema("information_schema", "key_column_usage"))
referential_constraints <- tbl(con, dbplyr::in_schema("information_schema", "referential_constraints"))
constraint_column_usage <- tbl(con, dbplyr::in_schema("information_schema", "constraint_column_usage"))

keys <- tables %>%
  left_join(table_constraints, by = c(
    "table_catalog" = "table_catalog",
    "table_schema" = "table_schema",
    "table_name" = "table_name"
  )) %>%
  # table_constraints %>%
  filter(constraint_type %in% c("FOREIGN KEY", "PRIMARY KEY")) %>%
  left_join(key_column_usage,
    by = c(
      "table_catalog" = "table_catalog",
      "constraint_catalog" = "constraint_catalog",
      "constraint_schema" = "constraint_schema",
      "table_name" = "table_name",
      "table_schema" = "table_schema",
      "constraint_name" = "constraint_name"
    )
  ) %>%
  # left_join(constraint_column_usage) %>% # does this table add anything useful?
  select(table_name, table_type, constraint_name, constraint_type, column_name, ordinal_position) %>%
  arrange(table_name) %>%
  collect()
glimpse(keys)

sp_print_df(head(keys))
```

Again, `dbGetQuery()` does not seem to get the desired results.
```
rs <- dbGetQuery(
  con,
  "SELECT r.*,
  pg_catalog.pg_get_constraintdef(r.oid, true) as condef
  FROM pg_catalog.pg_constraint r
  WHERE 1=1 --r.conrelid = '16485' AND r.contype = 'f' ORDER BY 1;
  "
)

head(rs)
```

End of Chapter 12:
```
dbDisconnect(con)
sp_docker_stop("adventureworks")
```

# Part B

# Chapter 2 - SQL Query Structure (This serves as a review from SQL I.)

Common clauses used:

- `SELECT`  determines the columns that will be returned by the query
- `FROM` determines the tables from which the expressions in the SELECT clause are derived. As we saw in Chapter 11, the `FROM` clause can connect multiple tables using a `JOIN` which serves as the condition on how the tables related to each other.
- `INNER JOIN` returns all records that match in both tables.
- `FULL OUTER JOIN` returns all records from both tables.
- `LEFT JOIN` returns all records from the first table and only the records from the second table that match. 
- `RIGHT JOIN` returns all records from the second table and only the records from the first table that match. 
- `WHERE` specifies a filter that can remove rows from the result set.
- `LIMIT` limits the results to avoid crashing databases when they are very large. 
- `GROUP BY` is required when the SELECT clause contains aggregations (like `COUNT`, `SUM` or `MAX`) and at least one nonaggregated field. For example,
```
SELECT CustomerID, SUM(Amount) AS TotalAmount
FROM Orders
GROUP BY CustomerID
;
```

Connecting to `adventureworks`:
```
sleep_default <- 3
sp_check_that_docker_is_up()

sp_docker_start("adventureworks")
Sys.sleep(sleep_default)

con <- dbConnect(          # use in other settings
  RPostgres::Postgres(),
  # without the previous and next lines, some functions fail with bigint data 
  #   so change int64 to integer
  bigint = "integer",  
  host = "localhost",
  port = 5432,  # this version still using 5432!!!
  user = "postgres",
  password = "psql",
  dbname = "adventureworks"
)

```

Use some of the SQL we have learned:
```
# setting default schema to sales
dbExecute(con, "set search_path to sales;")

#listing out all tables 
dbGetQuery(con, "
  SELECT table_name
  FROM information_schema.tables
  WHERE table_schema = 'sales'
  ORDER BY table_name;
")

#listing out all columns in the customer table 
dbGetQuery(con, "
  SELECT column_name
  FROM information_schema.columns
  WHERE table_name = 'customer';
")

```

## Chapter 5 - Text Analysis 

In SQL I, we saw Daniel go through a numerical analysis of the sales database in the `adventureworks` container. Using a UFO sightings dataset, we will go through some text analysis methods. 

Text analysis is the process of deriving meaning and insight from text data.
It can be split into two groups: qualitative analysis and quantitative analysis. 
*Quanlitative analysis* is when we want to understand and synthesize the meaning from a single text or a set of texts, often applying other knowledge or unique conclusions.
*Quantitative analysis* is when we want to synthesize(combine) information from text data, but the output is quantitative
SQL is much more suited to quantitative analysis, so that is what the rest of this chapter is concerned with.

Some goals of text analysis include:

- text extraction where we want to extra useful parts of the data,
- categorization where the information that is extracted from text data needs to be be assigned tags or categories,
- sentiment analysis where the goal is to understand the intent.

We will be working with a version of a ufo sightings dataset. First, we need to create a docker image and then run a container and copy the dataset in the container.
In terminal:
```
docker run -d \
  --name pg_ufo \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=ufo_db \
  -p 5433:5432 \
  -v $(pwd)/pgdata:/var/lib/postgresql/data \
  postgres:15


# -L is for location, -o is for output and specifies how the file will be saved
curl -L -o ufo_sightings.csv https://raw.githubusercontent.com/rfordatascience/tidytuesday/master/data/2019/2019-06-25/ufo_sightings.csv

docker exec -it pg_ufo psql -U postgres -c"CREATE DATABASE ufo_db;"

docker exec -i pg_ufo psql -U postgres -d ufo_db -c "
CREATE TABLE IF NOT EXISTS ufo_sightings (
    datetime TEXT,
    city TEXT,
    state TEXT,
    country TEXT,
    shape TEXT,
    duration_seconds FLOAT,
    duration TEXT,
    comments TEXT,
    date_posted TEXT,
    latitude FLOAT,
    longitude FLOAT
);"

#copying the csv into the container, it now exists in the container
docker cp ufo_sightings.csv pg_ufo:/ufo_sightings.csv

#we created a table earlier and now each row of the csv is read and put into the ufo_sightings table 
#additionally, NA's are converted to NULL to avoid errors 
docker exec -i pg_ufo psql -U postgres -d ufo_db -c "\copy ufo_sightings FROM '/ufo_sightings.csv' CSV HEADER NULL 'NA';"
```

Connecting to `ufo_db` and looking at what we are working with:
```
library(DBI)
library(sqlpetr)
sp_docker_start("pg_ufo")
con <- dbConnect(
  RPostgres::Postgres(),
  dbname = "ufo_db",
  host = "localhost", 
  port = 5433,
  user = "postgres",
  password = "postgres"
)

#printing the first 10 observations
dbGetQuery(con, "SELECT * FROM ufo_sightings
LIMIT 10
;")

#printing the column names
dbGetQuery(con, "SELECT column_name
FROM information_schema.columns
WHERE table_name = 'ufo_sightings'
;")
```

### Text Characteristics 
One way to get to know the data is through the number of characters in each value, which can be done with the `length` function.
An example of how `LENGTH` is used in SQL:
```
#command
SELECT length('Sample string');

#output
length
------
13
```

We can obtain the lengths of the ufo sighting description to get a sense of the typical length. 
In our dataset, the column name of interest is `comments`.
```
#SQL from the textbook 
SELECT length(sighting_report), count(*) as records
FROM ufo
GROUP BY 1
ORDER BY 1
;
 
#edited for our version
length_comments <- dbGetQuery(con, "SELECT length(comments), count(*) as records
FROM ufo_sightings
GROUP BY 1
ORDER BY 1
;")
length_comments
```
We get a list of length of comments and then the number of records that correspond to the length. At the end of the table, we see that NA occurred 15 times.

Getting a visualization of `length_comments`:
```
ggplot2::ggplot(length_comments, aes(x = length, y = records)) +
  geom_col(width = 0.8, fill = "steelblue") +
  labs(x = "Length", y = "Frequency") +
  theme_minimal()
```
From the histogram we can see that the frequency is sub 1000 for most character lengths and then a few frequencies of lengths between 125 and 150 shoots up.


In the textbook, they need to make the data more usable, but since we are working with a different dataset, it has already been cleaned up.
Thus, we already have columns corresponding to when the sighting occurred, comment, location, shape, duration etc.

### Text Parsing 
Parsing data is the process of extracting pieces of text.
In SQL we can parse data with the `left` and `right` functions. 
The `left` function returns characters from the left side of the string and the `right` function returns characters from the right side of the string. 
```
dbGetQuery(con, "SELECT left('The data is about UFOs',3) as left_digits
,right('The data is about UFOs',4) as right_digits
;")
```

We can parse out the first 8 characters using the `left` function:
```
dbGetQuery(con, "SELECT left(comments, 8) as left_digits
,count(*)
FROM ufo_sightings
GROUP BY 1
;")
```
We can see that all the descriptions of the sighting start a little differently, some name the location, some give a measurement and some start with a visual description.

For more complex patterns, a function called `split_part` is more useful. 
The idea behind this function is to split a string into parts based on a delimiter and then allow you to select a specific part. 
A delimiter is one or more characters that are used to specify the boundary between regions of text. 
The function is of the form:
```
split_part(string or field name, delimiter, index)
```
Example:
```
dbGetQuery(con, "SELECT split_part('This is an example of an example string'
                  ,'an example'
                  ,1);
")

dbGetQuery(con, "SELECT split_part('This is an example of an example string'
                  ,'an example'
                  ,2);
")
```

Extracts the month:
```
dbGetQuery(con, "SELECT split_part(datetime,'/',1) as split_month
FROM ufo_sightings
LIMIT 10
;")
```
Extracts the day: 
```
dbGetQuery(con, "SELECT split_part(datetime,'/',2) as split_day
FROM ufo_sightings
LIMIT 10
;")
```
Extracts the year and time:
```
dbGetQuery(con, "SELECT split_part(datetime,'/',3) as split_year
FROM ufo_sightings
LIMIT 10
;")

dbGetQuery(con, "SELECT split_part(date_posted,'/',3) as split_year
FROM ufo_sightings
LIMIT 10
;")
```

Extracting the year of ufo sighting posted and making a histogram:
```
split_year = dbGetQuery(con, "SELECT split_part(date_posted,'/',3) as split_year
FROM ufo_sightings
;")
hist(as.numeric(unlist(split_year)))
```
We can see more reported in 2011 and 2012 than other years.


### Text Transformations
Transformation for date and timestamps can be found in Chapter 3. 
One of the most common transformations are the ones that change capitalization. 
The `upper` function converts all letters to their uppercase form and the `lower` function converts all letters to their lowercase form. 
We may want to change the state appreviations so that they are capitalized:
```
dbGetQuery(con, "
SELECT upper(state) 
FROM ufo_sightings
;")
```

We can also make the first letter capitalized by using the `initcap` function:
```
dbGetQuery(con, "
SELECT city, initcap(city) as city_clean
FROM ufo_sightings
LIMIT 10
;")
```

The `trim` transformation removes blank spaces at the beginning and end of a string
```
dbGetQuery(con, "SELECT trim('  California  ');")
```

The replace transformation replaces or removes a word or phrase within a string. 
```
dbGetQuery(con, "SELECT replace('Some unidentified flying objects were noticed above...','unidentified flying objects','UFOs');")
```

Example in our ufo sightings data:
```
dbGetQuery(con, "SELECT replace(duration,'minutes','min')
FROM ufo_sightings
LIMIT 20
;")
```

We want to replace both minutes and seconds:
```
dbGetQuery(con, "SELECT duration, replace(replace(duration,'minutes','min'), 'seconds', 'secs') as duration_clean
FROM ufo_sightings
LIMIT 20
;")
```

Combining several data transformations (`upper`, `initcap`, and `replace`):
```
dbGetQuery(con, "
SELECT split_part(date_posted,'/',3) as year_recorded, upper(state) as State, initcap(city) as city, replace(replace(duration,'minutes','min'), 'seconds', 'secs') as duration
FROM ufo_sightings
LIMIT 10
;")
```
### Finding elements within larger blocks of text 
A common thing to do is find strings within a larger block of text. One way to do this is using SQL wildcards (which are special characters) within the `LIKE` and `ILIKE` operators. 
The `LIKE` operator matches the specified pattern within the string.
In order for it to find the pattern and not just the exact match, wildcard symbols can be added.
Some examples include:

- `%` matches zero or more characters 
- `_` matches exactly one character
- to match `%` or `_` specifically, a `\` is required.

Examples:

```
dbGetQuery(con, "SELECT 'this is an example string' like '%example%';")

dbGetQuery(con, "SELECT 'this is an example string' like '%abc%';")

dbGetQuery(con, "SELECT 'this is an example string' like '%this_is%';")

dbGetQuery(con, "SELECT 'this is an example string' like '%that_is%';")
```

The `LIKE` operator is good for filtering. 

Example:
```
dbGetQuery(con, "SELECT count(*)
FROM ufo_sightings
WHERE comments like '%wife%'
;")


dbGetQuery(con, "SELECT count(*)
FROM ufo_sightings
WHERE comments like '%alien%'
;")

dbGetQuery(con, "SELECT count(*)
FROM ufo_sightings
WHERE comments like '%spaceship%'
;")
```

Additionally, we can add case specific functions:
```
dbGetQuery(con, "SELECT count(*)
FROM ufo_sightings
WHERE lower(comments) like '%wife%'
;")

dbGetQuery(con, "SELECT count(*)
FROM ufo_sightings
WHERE lower(comments) like '%alien%'
;")
```
This now increases the count for wife form 491 to 562 and for alien from 126 to 205.

Another way this can be done is the ilike operator (though not supported by all databases, notably, MySQL and SQL Server):
```
dbGetQuery(con, "SELECT count(*)
FROM ufo_sightings
WHERE comments ilike '%wife%'
;")

dbGetQuery(con, "SELECT count(*)
FROM ufo_sightings
WHERE comments ilike '%alien%'
;")
```

We can also negate `LIKE` and `ILIKE` with `NOT`. For example, if were interested in the comments where alien is not mentioned:
```
dbGetQuery(con, "SELECT count(*)
FROM ufo_sightings
WHERE lower(comments) not like '%alien%'
;")
```

We can filtering on multiple strings with `AND` and `OR` operators:
```
dbGetQuery(con, "SELECT count(*)
FROM ufo_sightings
WHERE lower(comments) like '%wife%'
or lower(comments) like '%husband%'
;")
```

`OR` is evaluated before `AND` so you have to be careful about where you put it:
```
# this counts the rows the rows that mention wife or husband and mother together
dbGetQuery(con, "SELECT count(*)
FROM ufo_sightings
WHERE lower(comments) like '%wife%'
or lower(comments) like '%husband%'
and lower(comments) like '%mother%'
;")

#breaking it apart
dbGetQuery(con, "SELECT count(*)
FROM ufo_sightings
WHERE lower(comments) like '%wife%'
;")

dbGetQuery(con, "SELECT count(*)
FROM ufo_sightings
WHERE lower(comments) like '%husband%'
and lower(comments) like '%mother%'
;")

dbGetQuery(con, "SELECT count(*)
FROM ufo_sightings
WHERE lower(comments) like '%wife%'
and lower(comments) like '%husband%'
and lower(comments) like '%mother%'
;")

# this is counts rows that include mother as well as wife or husband
dbGetQuery(con, "SELECT count(*)
FROM ufo_sightings
WHERE (lower(comments) like '%wife%'
or lower(comments) like '%husband%'
      )
and lower(comments) like '%mother%'
;")
```


In previous examples we were filtering on `WHERE` but `LIKE` can also be used in the `SELECT` clause. 
We can find out how many descriptions contain specific terms and group them by using a `CASE` statement with `LIKE`:
```
dbGetQuery(con, "SELECT case when lower(comments) like '%driving%' then 'driving'
     when lower(comments) like '%walking%' then 'walking'
     when lower(comments) like '%running%' then 'running'
     when lower(comments) like '%cycling%' then 'cycling'
     when lower(comments) like '%swimming%' then 'swimming'
     when lower(comments) like '%eating%' then 'eating'
     when lower(comments) like '%sleeping%' then 'sleeping'
     else 'none' end as activity
,count(*)
FROM ufo_sightings
GROUP BY 1
ORDER BY 2 desc
;")
```

`LIKE` can be used to generate a `BOOLEAN` response of `TRUE` or `FALSE`, and we can use this to label rows.
```
dbGetQuery(con, "SELECT comments ilike '%south%' as south
,comments ilike '%north%' as north
,comments ilike '%east%' as east
,comments ilike '%west%' as west
,count(*)
FROM ufo_sightings
GROUP BY 1,2,3,4
ORDER BY 1,2,3,4
;")
```
The result is a matrix of `BOOLEANs` that can be used to find the frequency of various combinations of directions, or to find when a direction is used without any of the other directions in the same description.

But it may be more convenient to count each direction comes up in the comments:
```
dbGetQuery(con, "SELECT count(case when comments ilike '%south%' then 1 end) as south
,count(case when comments ilike '%north%' then 1 end) as north
,count(case when comments ilike '%west%' then 1 end) as west
,count(case when comments ilike '%east%' then 1 end) as east
FROM ufo_sightings
;")
```

### Exact Matches: IN, NOT IN
`IN` and `NOT IN` are often useful in combination with `LIKE` and its relatives in order to come up with a rule set that includes exactly the right set of results. 
These allow you to specify a list of matches, resulting in more compact code.

Suppose we are interested in categorizing the ufo sightings based on the first word of the description (`comments`).
We can find the first word using the `split_part` function (`SPLIT_PART(<string>, <delimiter>, <partNumber>)`), with a space character as the delimiter.
We can filter filter through the records to take a look at reports that start by naming a color.
This can be done by listing each color with an `OR` construction:
```
dbGetQuery(con, "SELECT first_word, comments
FROM
(
    SELECT split_part(comments,' ',1) as first_word
    ,comments
    FROM ufo_sightings
) a
WHERE first_word = 'Red'
or first_word = 'Orange'
or first_word = 'Yellow'
or first_word = 'Green'
or first_word = 'Blue'
or first_word = 'Purple'
or first_word = 'White'
LIMIT 20
;")
```
`a` here is a table alias where the output of the inner query is temporarily called a.
In SQL it is required that every subquery in the FROM clause has an alias unless you will get an error.

Using an `IN` list is more compact:
```
dbGetQuery(con, "SELECT first_word, comments
FROM
(
    SELECT split_part(comments,' ',1) as first_word
    ,comments
    FROM ufo_sightings
) a
WHERE first_word in ('Red','Orange','Yellow','Green','Blue','Purple','White')
LIMIT 20
;")
```

The main benefit of `IN` and `NOT IN` is that they make code more compact and readable. 
This can come in handy when creating more complex categorizations in the `SELECT` clause. 
For example, imagine we wanted to categorize and count the records by the first word into colors, shapes, movements, or other possible words. 
We might come up with something like the following that combines elements of parsing, transformations, pattern matching, and `IN` lists:
```
dbGetQuery(con, "SELECT 
case when lower(first_word) in ('red','orange','yellow','green', 
'blue','purple','white') then 'Color'
when lower(first_word) in ('round','circular','oval','cigar') 
then 'Shape'
when first_word ilike 'triang%' then 'Shape'
when first_word ilike 'flash%' then 'Motion'
when first_word ilike 'hover%' then 'Motion'
when first_word ilike 'pulsat%' then 'Motion'
else 'Other' 
end as first_word_type
,count(*)
FROM
(
    SELECT split_part(comments,' ',1) as first_word
    ,comments
    FROM ufo_sightings
) a
GROUP BY 1
ORDER BY 2 desc
;")
```
The last two lines here, mean that we want to group by the first column which is `first_word_type ` and then order the second column in descending order which is the `count` column.

### Regular Expressions
There are a number of ways to match patterns in SQL, one of the most powerful methods is the use of regular expressions (regex). 
Regular expressions are sequences of characters with special meanings, that define search patterns. 
The main challenge in learning regex is that the syntax is not particularly intuitive.

Regex can be used in SQL statements in a couple of ways. The first is with POSIX comparators, and the second is with regex functions. 
POSIX stands for Portable Operating System Interface, some of the comparators include:

- `~` compares two statements and returns `TRUE` if one is contained in the other (it is case sensitive),
- `~*` compares two statements and returns `TRUE` if one is contained in the other (not case sensitive),
- `!~` compares two statements and returns `FALSE` if one is contained in the other (it case sensitive),
- `!~*` compares two statements and returns `FALSE` if one is contained in the other (not case sensitive).
Examples:
```
dbGetQuery(con, 
"SELECT 
'The data is about UFOs' ~ '. data' as comparison_1
,'The data is about UFOs' ~ '.The' as comparison_2
;")
```

Additionally, we can match multiple characters using the * (asterisk) symbol. 
This use of the asterisk is different from placing it immediately after the tilde (~*), which makes the match case insensitive. 
```
dbGetQuery(con, 
"SELECT 'The data is about UFOs' ~ 'data *' as comparison
;")
```

The next special characters to know are [ and ] (left and right brackets). 
These are used to enclose a set of characters, any one of which must match.
```
dbGetQuery(con, 
"SELECT 'The data is about UFOs' ~ '[Tt]he' as comparison_1
,'the data is about UFOs' ~ '[Tt]he' as comparison_2
,'tHe data is about UFOs' ~ '[Tt]he' as comparison_3
,'THE data is about UFOs' ~ '[Tt]he' as comparison_4
;")
```
Another use of the bracket set match is to match a pattern that includes a number, allowing for any number.
```
dbGetQuery(con, 
"SELECT 'sighting lasted 8 minutes' ~ '[789] minutes' as comparison
;")

dbGetQuery(con, 
"SELECT 'sighting lasted 8 minutes' ~ '[6-9] minutes' as comparison
;")

dbGetQuery(con, 
"SELECT 'driving on 495 south' ~ 'on [0-9][0-9][0-9]' as comparison
;")

dbGetQuery(con, 
"SELECT 
'driving on 495 south' ~ 'on [0-9]+' as comparison_1
,'driving on 1 south' ~ 'on [0-9]+' as comparison_2
,'driving on 38east' ~ 'on [0-9]+' as comparison_3
,'driving on route one' ~ 'on [0-9]+' as comparison_4
;")
```
Summary of regex range patterns:

- [0-9] for any number
- [a-z] for any lowercase letter
- [A-Z] for any uppercase letter
- [A-Za-z0-9]	Match any lower- or uppercase letter, or any number
- [A-z]	Match any ASCII character (generally not used because it matches everything including symbols)


An alternative to `~` is to use `refexp_like` or `rlike`. 
`refexp_like` is formatted as `regexp_like(string, pattern, optional_parameters)`. 
```
dbGetQuery(con, "SELECT regexp_like('The data is about UFOs','data') 
 as comparison
 ;")
```

We can also find and replace with regex. Here we find expressions that include a number of lights:
```
dbGetQuery(con, "SELECT left(comments,50)
FROM ufo_sightings
WHERE left(comments,50) ~ '[0-9]+ light[s ,.]'
LIMIT 20 
;")
```
We might want to split out just the part that refers to the number and the word “lights.” To do this, we’ll use the regex function `regexp_matches`.
```
dbGetQuery(con, "SELECT (regexp_matches(comments,'[0-9]+ light[s ,.]'))[1]
,count(*)
FROM ufo_sightings
WHERE comments ~ '[0-9]+ light[s ,.]'
GROUP BY 1
ORDER BY 2 desc
; ")
```
We can then find the min and max number of light:
```
dbGetQuery(con, "SELECT min(split_part(matched_text,' ',1)::int) as min_lights
,max(split_part(matched_text,' ',1)::int) as max_lights
FROM
(
    SELECT (regexp_matches(comments
                           ,'[0-9]+ light[s ,.]')
                           )[1] as matched_text
    ,count(*)
    FROM ufo_sightings
    WHERE comments ~ '[0-9]+ light[s ,.]'
    GROUP BY 1
) a
;")
```

We can also replace strings with `regexp_replace`. 
`regexp_replace` is formatted as `regexp_replace(field or string, pattern, replacement value)`. 

Here we want to first look at the different durations:
```
dbGetQuery(con, "SELECT duration
,count(*) as reports
FROM ufo_sightings
GROUP BY 1
ORDER BY 2 desc
LIMIT 20
;")
```

We now want to use `regexp_matches` to see which durations include minutes.
Note the textbook uses `'\m[Mm][Ii][Nn][A-Za-z]*\y'` to search through strings but this does not work with PostgreSQL regex.
```
dbGetQuery(con, "SELECT duration
,(regexp_matches(duration
                 ,'[Mm][Ii][Nn][A-Za-z]*')
                 )[1] as matched_minutes
FROM
(
    SELECT duration
    ,count(*) as reports
    FROM ufo_sightings
    GROUP BY 1
    ORDER BY 2 desc
) a
LIMIT 20
;")
```
Now, we can replace the different minute variations as just min:
```
dbGetQuery(con, "SELECT duration
,(regexp_matches(duration
                 ,'[Mm][Ii][Nn][A-Za-z]*')
                 )[1] as matched_minutes
,regexp_replace(duration
                 ,'[Mm][Ii][Nn][A-Za-z]*'
                 ,'min') as replaced_text
FROM
(
    SELECT duration
    ,count(*) as reports
    FROM ufo_sightings
    GROUP BY 1
    ORDER BY 2 desc
) a
LIMIT 20
;")

```
### Constructing and Reshaping text 

New text can be created with concatenation (`concat`). 
```
dbGetQuery(con, "SELECT concat('There were ',
         sum(reports),
         ' reports of ',
         lower(shape),
         ' objects for a duration of ',
         duration,
         '.'
  ) AS summary
FROM (
    SELECT 
      shape,
      duration,
      count(*) AS reports
    FROM ufo_sightings
    GROUP BY shape, duration
) a
GROUP BY shape, duration
ORDER BY sum(reports) DESC
LIMIT 20
;")
```

Disconnecting:
```
dbDisconnect(con)
sp_docker_stop("pg_ufo")
```

## Chapter 6 - Anomaly Detection
I don't think we will have time but if we get to Chapter 6 this is the following setup:
```
docker run -d \
  --name pg_earthquakes \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=earthquakes_db \
  -p 5434:5432 \
  -v $(pwd)/pgdata:/var/lib/postgresql/data \
  postgres:15

curl -L -o earthquakes.csv https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_month.csv

docker exec -it pg_earthquakes psql -U postgres -c"CREATE DATABASE earthquakes_db;"

docker exec -i pg_earthquakes psql -U postgres -d earthquakes_db -c "
CREATE TABLE IF NOT EXISTS earthquakes (
    time TIMESTAMP,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    depth DOUBLE PRECISION,
    mag DOUBLE PRECISION,
    magType TEXT,
    nst INTEGER,
    gap DOUBLE PRECISION,
    dmin DOUBLE PRECISION,
    rms DOUBLE PRECISION,
    net TEXT,
    id TEXT PRIMARY KEY,
    updated TIMESTAMP,
    place TEXT,
    type TEXT,
    horizontalError DOUBLE PRECISION,
    depthError DOUBLE PRECISION,
    magError DOUBLE PRECISION,
    magNst INTEGER,
    status TEXT,
    locationSource TEXT,
    magSource TEXT
);"

docker cp earthquakes.csv pg_earthquakes:/earthquakes.csv

docker exec -i pg_earthquakes psql -U postgres -d earthquakes_db -c "\copy earthquakes FROM '/earthquakes.csv' CSV HEADER;"
```

Connecting to `earthquakes_db` in R and looking at what we are working with:
```
library(DBI)
library(sqlpetr)
sp_docker_start("pg_earthquakes")
con <- dbConnect(
  RPostgres::Postgres(),
  dbname = "earthquakes_db",
  host = "localhost", 
  port = 5434,
  user = "postgres",
  password = "postgres"
)

#printing the first 10 observations
dbGetQuery(con, "SELECT * FROM earthquakes
LIMIT 10
;")

#printing the column names
dbGetQuery(con, "SELECT column_name
FROM information_schema.columns
WHERE table_name = 'earthquakes'
;")
```

With `dbGetQuery` one can go through all the chapter 6 (unlike chapter 5 where all of it had to be adapted), for example:
```
dbGetQuery(con, "SELECT mag
FROM earthquakes
ORDER BY 1 desc
;")
```

Disconnecting:
```
dbDisconnect(con)
sp_docker_stop("pg_earthquakes")
```

