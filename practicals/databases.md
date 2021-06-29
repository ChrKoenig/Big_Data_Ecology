Databases
================
Christian König

**This practical exercise is a part of the workshop [Big Data
Ecology](https://github.com/ChrKoenig/Big_Data_Ecology)**

------------------------------------------------------------------------

## Introduction

In this practical, we explore how to work with relational data in
relational database managament systems (`SQLite`) and in `R`. Our
practice dataset comes from the [Portal Project Teaching
Database](https://figshare.com/articles/dataset/Portal_Project_Teaching_Database/1314459),
which is a simplified version of the [Portal
Project](https://portal.weecology.org/) database. Follow the links and
make yourself familiar with the project.

We will use the following packages:

``` r
library(dplyr)
library(dbplyr)
library(RSQLite)
```

If you haven’t installed them, please do so with the following command:

``` r
install.packages(c("dplyr", "dbplyr", "RSQLite"))
```

## Data manipulation in SQL

First, we create a subfolder named `data` in our project folder, which
will hold all data required during the practicals and the course
project. Next, we download the `sqlite` version of the Portal Project
teaching DB from Figshare into the `data` folder.

``` r
download.file("https://ndownloader.figshare.com/files/11188550", destfile = "data/portal_mammals.sqlite") 
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
the dataset itself. Let’s have a closer look at the `plots` table by
listing all of its fields (columns).

``` r
RSQLite::dbListFields(conn, "plots")
```

    ## [1] "plot_id"   "plot_type"

### Our first SQL query

Now let’s count all records (rows) in `plots`.

For that, we need to write our first SQL query. We start the query with
the `SELECT` statement, which tells SQL that we want to extract data
from the database. Since we are interested in the number of rows in the
table `plots`, we simply count all records with the summary function
`COUNT()`. Finally, we use `AS` to give the results column a more
expressive name, called an ‘Alias’. The complete query looks like this:

``` r
RSQLite::dbGetQuery(conn, "SELECT COUNT(*) AS n_row FROM plots")
```

    ##   n_row
    ## 1    24

#### Exercise - Database structure and design

-   Repeat the above commands for the other two tables
-   What do you think is the schema of this database?
-   What are the `primary keys` of the tables and what might be their
    [relationships](https://www.ibm.com/docs/en/mam/7.6.0?topic=structure-database-relationships)?
-   Which table contains the actual field data, and which tables contain
    meta-information?

### Selecting columns and rows

We can select specific columns of the results table by simply listing
their names after the `SELECT` statement:

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

SQL also allows us to sort our results by columns
(`ORDER BY <column1>, <column2> ASC|DESC`), return only unique records
(`SELECT DISTINCT`), or return only a specified number of records
(`LIMIT <n>`)

### More complex queries - joining and aggregating data

The true power of SQL shows when extracting data across multiple tables
or producing data summaries

From the exercise above, you have certainly figured out that the
`survey` table contains the field data while the `species` and `plots`
tables respectively hold additional information on the study species
(species\_id, genus, species, taxa) and plot (plot\_id, plot\_type). We
can use the *id columns* `plot_id` and `species_id` to relate these
tables and query them collectively. The key operation for this purpose
is `JOIN`.

Recall from the lecture that `JOIN` combines the rows of two tables
based on a related column. For example, we might be interested in all
surveys that found *Dipodomys*, but the `surveys` table does not have a
`genus` column. Thus, we need to `JOIN` information from the `species`
table based on the `species_id` column. We specify this with the `ON`
clause. Note that for longer queries, we break up the code into multiple
lines.

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

#### Exercise - SQL

We have seen some of the core concepts of data manipulation in SQL. Now
try to use SQL to answer the following questions:

-   Which plot type has been surveyed most frequently?
-   For how many years are survey data available? (Tip: read up on the
    `DISTINCT` clause or use the `MIN()` and `MAX()` functions)
-   In which plot type was the species *Dipodomys merriami* found most
    frequently?

## Data manipulation in `dplyr`

Ok, the last exercise question was pretty hard, but that brings us to
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

These functions can be stringed together using the so-called ‘pipe’
operator: `%>%`. Moreover, they integrate seamlessly with `dplyr`’s
`group_by` function to run grouped calculations on your dataset.

#### Exercise - dplyr

Use `dplyr` to answer the following questions:

-   xxx
-   xxx
-   xxx

Finally, after we finished working with the Portal Project database, we
close the connection. This is good practice, especially when querying a
database programmatically.

``` r
RSQLite::dbDisconnect(conn)
```
