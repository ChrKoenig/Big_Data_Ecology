Databases
================
Christian König

**This practical exercise is a part of the workshop [Big Data
Ecology](https://github.com/ChrKoenig/Big_Data_Ecology)**

------------------------------------------------------------------------

## Introduction

In this practical, we explore how to work with relational data in
`SQLite` and `R`. For the purpose of this exercise, we will use a
dataset from the [Portal Project Teaching
Database](https://figshare.com/articles/dataset/Portal_Project_Teaching_Database/1314459),
which is a simplified version of the [Portal
Project](https://portal.weecology.org/) database. Take a second to
follow the links and make yourself familiar with the project.

We will use the following packages:

``` r
library(dplyr)
library(RSQLite)
```

If you haven’t installed them, please do so with the following command:

``` r
install.packages(c("dplyr", "RSQLite"))
```

## Data manipulation in SQL

First, we go to our version controlled course project folder and create
a subfolder named `data`, which will hold all data required during the
practicals and the course project. Next, we download the `sqlite`
version of the Portal Project teaching DB from Figshare into the `data`
folder.

``` r
download.file("https://ndownloader.figshare.com/files/11188550", destfile = "data/portal_mammals.sqlite") # TODO: This didn't work on Windows machines, Double-check download source
```

Instead of loading all data from the database into R, we want to perform
the operations directly within the database and retrieve only the
results. For that, we need to establish a connection between `R` and the
database. We can use the `dbConnect()` function from the `RSQLite`
package for this.

``` r
conn = RSQLite::dbConnect(RSQLite::SQLite(), dbname = "data/portal_mammals.sqlite") # open connection
RSQLite::dbListTables(conn)   # list tables in connected DB
```

    ## [1] "plots"   "species" "surveys"

The database has three tables, but we still don’t know very much about
the organization of the data. Let’s have a closer look at the `plots`
table by listing all of its fields (columns).

``` r
RSQLite::dbListFields(conn, "plots")
```

    ## [1] "plot_id"   "plot_type"

### Our first SQL query

Now let’s count all records (rows) in `plots`.

For that, we need to write our first SQL query. We start the query with
the `SELECT` clause, which tells SQL that we want to extract data from
the database. Since we are interested in the number of rows in the table
`plots`, we simply count all records with the summary function
`COUNT()`. Finally, we use `AS` to give the results column a more
expressive name, called an ‘Alias’. The complete query looks like this:

``` r
RSQLite::dbGetQuery(conn, "SELECT COUNT(*) AS n_row FROM plots")
```

    ##   n_row
    ## 1    24

### Exercise - Database structure and design

-   Repeat the above commands for the other two tables
-   What do you think is the schema of this database?
-   What are the `primary keys` of the tables and what might be their
    [relationships](https://www.ibm.com/docs/en/mam/7.6.0?topic=structure-database-relationships)?
-   Which table contains the actual field data, and which tables contain
    meta-information?

### Selecting columns and rows

We can select specific columns of the results table by simply listing
their names after `SELECT`:

``` r
RSQLite::dbGetQuery(conn, "SELECT species_id, genus, species FROM species")
```

    ##    species_id            genus         species
    ## 1          AB       Amphispiza       bilineata
    ## 2          AH Ammospermophilus         harrisi
    ## 3          AS       Ammodramus      savannarum
    ## 4          BA          Baiomys         taylori
    ....

Rows, on the other hand, can be filtered based on column values using
the `WHERE` clause. For example, if we only want species of the genus
*Dipodomys* from the table `species`, we write the following query:

``` r
RSQLite::dbGetQuery(conn, "SELECT * FROM species WHERE genus = 'Dipodomys'")
```

    ##   species_id     genus     species   taxa
    ## 1         DM Dipodomys    merriami Rodent
    ## 2         DO Dipodomys       ordii Rodent
    ## 3         DS Dipodomys spectabilis Rodent
    ## 4         DX Dipodomys         sp. Rodent

SQL allows us to manipulate our table in many other ways, e.g. to sort
our results by columns (`ORDER BY <column1>, <column2> ASC|DESC`),
return only unique records (`SELECT DISTINCT`), or return only a
specified number of records (`LIMIT <n>`)

### More complex queries - joining and aggregating data

The true power of SQL shows when extracting data across multiple tables
or producing data summaries

From the exercise above, you have certainly figured out that the
`survey` table contains the field data while the `species` and `plots`
tables respectively hold additional information on the study species
(`species_id, genus, species, taxa`) and plot (`plot_id, plot_type`). We
can use the id columns `plot_id` and `species_id` to relate the three
database tables and query them collectively. The key operation for this
purpose is `JOIN`.

Recall from the lecture that `JOIN` combines the rows of two tables
based on a related column. For example, we might be interested in all
surveys that found a species of *Dipodomys*, but the `surveys` table
does not have a `genus` column. Thus, we need to `JOIN` information from
the `species` table based on the `species_id` column. We specify the
column that two tables should be joined by with the `ON` clause. Note
that for longer queries, we break up the code into multiple lines.

``` r
RSQLite::dbGetQuery(conn, "SELECT surveys.month, surveys.day, surveys.year, species.genus 
                           FROM surveys
                           LEFT JOIN species 
                           ON surveys.species_id = species.species_id
                           WHERE species.genus = 'Dipodomys'")
```

    ##       month day year     genus
    ## 1         1   1 1982 Dipodomys
    ## 2         1   1 1982 Dipodomys
    ## 3         1   1 1982 Dipodomys
    ## 4         1   1 1982 Dipodomys
    ....

Finally, let’s have a look at data aggregation in SQL. We’ve already
seen the `COUNT()` function, which is one of several so-called aggregate
functions (including also `AVG()`, `SUM()`, `MIN()`, `MAX()`). These
functions can be used to summarize a table either as a whole (as we’ve
seen above), or by a grouping variable using the `GROUP BY` clause. For
example, we can count the number of records per genus in the surveys
table with the following statement:

``` r
RSQLite::dbGetQuery(conn, "SELECT species.genus, COUNT(*) AS n_records
                           FROM surveys
                           LEFT JOIN species 
                           ON surveys.species_id = species.species_id
                           GROUP BY species.genus")
```

    ##               genus n_records
    ## 1              <NA>       763
    ## 2        Ammodramus         2
    ## 3  Ammospermophilus       437
    ## 4        Amphispiza       303
    ....

### Exercise - SQL queries

We have seen some of the core concepts of data manipulation in SQL. Now
try to use SQL to answer the following questions:

-   Which plot type has been surveyed most frequently? (Tip: `JOIN` the
    `plots` table instead of the `species` table)
-   For how many years are survey data available? (Tip: read up on the
    `DISTINCT` clause or use the `MIN()` and `MAX()` functions)
-   In which plot type was the species *Dipodomys merriami* found most
    frequently? (Tip: you need two `JOIN`s for this)

## Data manipulation in `dplyr`

Ok, that last exercise question was pretty hard, but that brings us to
our next topic: `dplyr`. `dplyr` takes the main concepts of SQL-style
data manipulation and abstracts them into a set of coherent,
easy-to-understand R functions:

> -   mutate() adds new variables that are functions of existing
>     variables
> -   select() picks variables based on their names.
> -   filter() picks cases based on their values.
> -   summarise() reduces multiple values down to a single summary.
> -   arrange() changes the ordering of the rows.
>
> (source: <https://dplyr.tidyverse.org/>)

These core functions are complemented by numerous more specialized
function, and can be stringed together using the so-called ‘pipe’
operator: `%>%`. Moreover, they integrate seamlessly with `dplyr`’s
`group_by()` function to perform grouped manipulations of your dataset.
While `dplyr` offers nothing that could, in principle, not be done in
`base R`, its greatest advantage is its consistency and versatility. For
example, `dyplr` has exactly *one* verb/function to select columns from
a dataframe based on their names
(`dplyr::select(df, c("col1", "col2"))`), whereas in `base R` there is a
plethora of alternatives with [potentially surprising
behaviour](https://stackoverflow.com/a/10085807/3070022) (e.g.:
`df[c("col1","col2)]`, `subset(df, c("col1","col2"))`,
`df[,c("col1","col2")]`) .

Let’s have a closer look! We first need to load the database tables into
`R` and assign them to objects:

``` r
species = RSQLite::dbGetQuery(conn, "SELECT * FROM species")
plots   = RSQLite::dbGetQuery(conn, "SELECT * FROM plots")
surveys = RSQLite::dbGetQuery(conn, "SELECT * FROM surveys")
```

Now let’s recreate some of the SQL queries from above in `dplyr`:

**Selecting columns:**

``` r
species %>% dplyr::select(species_id, genus, species)
```

    ##    species_id            genus         species
    ## 1          AB       Amphispiza       bilineata
    ## 2          AH Ammospermophilus         harrisi
    ## 3          AS       Ammodramus      savannarum
    ## 4          BA          Baiomys         taylori
    ....

**Filtering rows:**

``` r
species %>% dplyr::filter(genus == "Dipodomys")
```

    ##   species_id     genus     species   taxa
    ## 1         DM Dipodomys    merriami Rodent
    ## 2         DO Dipodomys       ordii Rodent
    ## 3         DS Dipodomys spectabilis Rodent
    ## 4         DX Dipodomys         sp. Rodent

**Joins:**

``` r
surveys %>% 
  dplyr::left_join(species, by = "species_id") %>% 
  dplyr::filter(genus == "Dipodomys") %>% 
  dplyr::select(month, day, year, genus)
```

    ##       month day year     genus
    ## 1         7  16 1977 Dipodomys
    ## 2         7  16 1977 Dipodomys
    ## 3         7  16 1977 Dipodomys
    ## 4         7  16 1977 Dipodomys
    ....

**Aggregation:**

``` r
surveys %>% 
  dplyr::left_join(species, by = "species_id") %>% 
  dplyr::group_by(genus) %>% 
  dplyr::summarise(n_records = n())
```

    ## # A tibble: 27 x 2
    ##    genus            n_records
    ##    <chr>                <int>
    ##  1 Ammodramus               2
    ##  2 Ammospermophilus       437
    ....

You may have noticed that the last results table does not seem to be
identical to our earlier SQL query. That is because `dplyr` has
implicitly converted the `data.frame` into a `tibble` when calling
`group_by()`. A `tibble` has improved printing and subsetting methods
compared to `data.frame`, but should otherwise behave the same.

This short session has given us a glimpse at `dplyr`’s capabilities. The
`dplyr` package is at the heart of the `tidyverse`, a much larger and
ever-growing ecosystem of `R`-packages that implement the philosphy of
[*tidy* data](https://r4ds.had.co.nz/tidy-data.html).

### Exercise - dplyr

-   Read the linked section on tidy data

Use `dplyr` to answer the following questions:

-   Verify that the number of records per genus produced by `SQL` and
    `dplyr` is identical, although the print output differs
-   Tackle the previous question “In which plot type was the species
    *Dipodomys merriami* found most frequently?” again with `dplyr`. Use
    the following code template and replace the `<...>` placeholders:

``` eval
plot_count_DM = surveys %>% 
  <...>_join(<...>, by = <...>) %>%   # Join plots table
  <...>_join(<...>, by = <...>) %>%   # Join species table
  dplyr::filter(species_id == <...>) %>%   # Subset to Dipodomys merriami
  group_by(<...>) %>%    # Group by the variable we want to summarize
  summarise(n_records = <...>)   # count records per variable level
```

At last, we close the connection to the Portal Project database. This is
good practice, especially when querying a database server via a remote
connection.

``` r
RSQLite::dbDisconnect(conn)
```

## Some final notes

We have now finished our excursion into relational databases and data
management. The concepts you have learned illustrate how disparate
datasets (and databases!) can be linked by means of shared identifiers.
Moreover, the efficiency and reliability of your own data processing
workflows will benefit greatly from adopting a modern, well-designed
framework such as the `tidyverse`.
