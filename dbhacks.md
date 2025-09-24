## miscellaneous BB notes

Still not getting connections/tables etc.

go into container with bash

psql -d Adventureworks -U postgres

\dt *.*

## R stuff

> tt <- tbl(con, "salesorderheader")
> tt |> summarize(n())

## not sure if pull() will try to grab the whole vector ...
tt |> select(salesorderid) |> summarize(across(everything(), max))
tt |> select(salesorderid) |> summarize(across(everything(), list(min,max)))

```r
tbl(con, "salesorderheader") |>
  select(order_date = orderdate) |>
  show_query()
```

```{r}
tt0 <- tt |>
  select(subtotal, contains("date")) |>
    mutate(today = now())

tt0 |> show_query()
tt0 |> collect()
```

`.by` syntax ...
