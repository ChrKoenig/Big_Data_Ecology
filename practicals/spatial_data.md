Spatial data in R
================
Christian König & Damaris Zurell

**This practical exercise is a part of the workshop [Big Data
Ecology](https://github.com/ChrKoenig/Big_Data_Ecology)**

------------------------------------------------------------------------

## Introduction

Here, we focus on spatial data, a central data type in ecology.
Following the content of the lecture, we will work with vector and
raster data and perform a number of operations based on their
attributes, geometries and spatial relationships.

We will use the following packages:

``` r
library(sf)
library(raster)
library(rnaturalearth)
library(dplyr)
library(ggplot2)
```

If you haven’t installed them, please do so with the following command:

``` r
install.packages(c("sf", "raster", "rnaturalearth", "dplyr", "ggplot2"))
```

## Vector data

Vector data are typically used to represent discrete objects with clear
boundaries such as, e.g., individual trees, roads, or countries. In
addition to their spatial definition, vector data may carry information
that describes the spatial features, e.g. the species of the tree, the
type of the road, or name of the country. These additional information
are called attributes.

### Vector data types

There are three fundamental types of vector data:

-   **Points** occur at discrete locations and are represented by a
    coordinate pair (x,y).
-   **Lines** describe linear features and are defined by at least two
    coordinate pairs (x,y), the end points of the line. A line can also
    consistent of several line segments.
-   **Polygons** describe two-dimensional features in the landscapes and
    define a bounded area, enclosed by lines. Thus, a polygon needs to
    consist of at least three coordinate pairs (x,y).

The `sf` package provides a set of vector data classes and methods
(*simple features*) that follow the *tidy* data model we already met in
the context of data bases. In fact, the *simple feature* standard is
language-independent and has been [adopted by many geospatial analysis
and database
platforms](https://en.wikipedia.org/wiki/Simple_Features#Implementations).
You can think of a *simple feature* as a normal data frame where each
row corresponds to one spatial entity, with the coordinates/geometries
of these entities being stored in a special column. Additional
attributes can be simply added as new columns. This design makes *simple
features* compatible with SQL-style data manipulation while maintaining
full integrity of spatial and attribute data.

### Point features

Let’s create a set of 20 points with random longitude and latitude
values:

``` r
set.seed(1)
coords = data.frame(
  longitude = runif(n = 20, min = -180, max = 180),
  latitude = runif(n = 20, min = -90, max = 90)
)
plot(coords)
```

![](spatial_data_files/figure-gfm/unnamed-chunk-3-1.png)<!-- -->

Now we use the `sf`package to convert this coordinate data frame into a
collection of simple point features.

``` r
points_sf = sf::st_as_sf(coords, coords = c("longitude", "latitude"), crs = 4326)  
points_sf
```

    ## Simple feature collection with 20 features and 0 fields
    ## geometry type:  POINT
    ## dimension:      XY
    ## bbox:           xmin: -157.7569 ymin: -87.58974 xmax: 177.0862 ymax: 78.24694
    ## geographic CRS: WGS 84
    ## First 10 features:
    ##                       geometry
    ## 1   POINT (-84.41688 78.24694)
    ## 2   POINT (-46.0354 -51.81435)
    ## 3    POINT (26.22721 27.30128)
    ## 4   POINT (146.9548 -67.40008)
    ## 5  POINT (-107.3945 -41.90028)
    ## 6   POINT (143.4203 -20.49946)
    ## 7   POINT (160.0831 -87.58974)
    ## 8   POINT (57.88721 -21.17017)
    ## 9    POINT (46.48106 66.54435)
    ## 10 POINT (-157.7569 -28.73718)

The print method outputs an informative summary of our new `sf` object:
It’s a simple feature collection of 20 point features. These points are
defined in two dimensions (XY) and have no additional attributes. Also
note that the EPSG code provided to the `CRS` argument of the
`st_as_sf()` function is sufficient to fully define the coordinate
reference system (CRS) of our spatial object.

Next, we use the very same manipulation tools as for other tidy data to
add an attribute column to `points_sf`. Specifically, we use the
`mutate()` verb known from `dplyr` for this task:

``` r
points_sf = points_sf %>% 
  mutate(name = sample(LETTERS[1:5], 20, replace = T)) # Add random letters as new attribute 'name'
points_sf
```

    ## Simple feature collection with 20 features and 1 field
    ## geometry type:  POINT
    ## dimension:      XY
    ## bbox:           xmin: -157.7569 ymin: -87.58974 xmax: 177.0862 ymax: 78.24694
    ## geographic CRS: WGS 84
    ## First 10 features:
    ##                       geometry name
    ## 1   POINT (-84.41688 78.24694)    B
    ## 2   POINT (-46.0354 -51.81435)    D
    ## 3    POINT (26.22721 27.30128)    D
    ## 4   POINT (146.9548 -67.40008)    D
    ## 5  POINT (-107.3945 -41.90028)    B
    ## 6   POINT (143.4203 -20.49946)    D
    ## 7   POINT (160.0831 -87.58974)    A
    ## 8   POINT (57.88721 -21.17017)    A
    ## 9    POINT (46.48106 66.54435)    D
    ## 10 POINT (-157.7569 -28.73718)    A

### Line and Polygon features

The structure of simple line and polygon features is analogous to simple
point features, the only difference being that the geometry column now
holds multiple coordinates to define the shape of the features. We’ll
confirm this by aggregating `points_sf` to one line feature per name.

``` r
lines_sf = points_sf %>% 
  group_by(name) %>%     # group by name
  filter(n() > 1) %>%    # lines need more than 1 point
  summarise(do_union = F) %>%  # Don't union geometries
  st_cast("LINESTRING")  # Create one line feature per group
lines_sf
```

    ## Simple feature collection with 4 features and 1 field
    ## geometry type:  LINESTRING
    ## dimension:      XY
    ## bbox:           xmin: -157.7569 ymin: -87.58974 xmax: 177.0862 ymax: 78.24694
    ## geographic CRS: WGS 84
    ## # A tibble: 4 x 2
    ##   name                                                                  geometry
    ##   <chr>                                                         <LINESTRING [°]>
    ## 1 A     (160.0831 -87.58974, 57.88721 -21.17017, -157.7569 -28.73718, 78.34266 …
    ## 2 B     (-84.41688 78.24694, -107.3945 -41.90028, -105.8492 -3.225579, 67.32822…
    ## 3 C                 (-116.4396 17.92185, 177.0862 -70.57015, -43.18734 40.26797)
    ## 4 D     (-46.0354 -51.81435, 26.22721 27.30128, 146.9548 -67.40008, 143.4203 -2…

Finally, let’s plot our spatial objects using the `ggplot2` package:

``` r
ggplot() +
  geom_sf(data = lines_sf, aes(color = name)) +
  geom_sf(data = points_sf) 
```

![](spatial_data_files/figure-gfm/unnamed-chunk-7-1.png)<!-- -->

## Raster data

We will use the `raster` package to represent and analyse raster data in
`R`. The package contains different data classes, most importantly
`RasterLayer`, `RasterStack` and `RasterBrick`. `RasterLayers` contain
only a single layer of values while `RasterStacks` and `RasterBricks`
contain multiple layers (from separate files or from a single
multi-layer file, respectively).

### RasterLayers, RasterStacks and RasterBricks

The function `raster()` can be used to create RasterLayer objects. We’ll
create a continuous global grid of 10x10-degree raster cells. For
illustration purposes, we set the CRS this time with a proj4 string.

``` r
r1 = raster(ncol=36, nrow=18, xmx=180, xmn=-180, ymx=90,  ymn=-90)
crs(r1) = "+proj=longlat +datum=WGS84 +no_defs" # set Proj4 string
r1
```

    ## class      : RasterLayer 
    ## dimensions : 18, 36, 648  (nrow, ncol, ncell)
    ## resolution : 10, 10  (x, y)
    ## extent     : -180, 180, -90, 90  (xmin, xmax, ymin, ymax)
    ## crs        : +proj=longlat +datum=WGS84 +no_defs

`RasterLayers` can only possess one attribute/value per cell. We use the
`values()` function to access the attributes of the `raster` object and
assign some random values.

``` r
values(r1) = rnorm(ncell(r1)) # assign random values
plot(r1)   # plot raster
```

![](spatial_data_files/figure-gfm/unnamed-chunk-9-1.png)<!-- -->

`RasterStack` and `RasterBrick` objects can be created with the
`stack()` and `brick()` function, respectively. Note that this only
works when all rasters have the same spatial extent and resolution.

``` r
r2 = r1 # Copy r1 into new object

stack(r1,r2) # Create RasterStack 
```

    ## class      : RasterStack 
    ## dimensions : 18, 36, 648, 2  (nrow, ncol, ncell, nlayers)
    ## resolution : 10, 10  (x, y)
    ## extent     : -180, 180, -90, 90  (xmin, xmax, ymin, ymax)
    ## crs        : +proj=longlat +datum=WGS84 +no_defs 
    ## names      :   layer.1,   layer.2 
    ## min values : -3.008049, -3.008049 
    ## max values :  3.810277,  3.810277

``` r
brick(r1,r2) # Create RasterBrick
```

    ## class      : RasterBrick 
    ## dimensions : 18, 36, 648, 2  (nrow, ncol, ncell, nlayers)
    ## resolution : 10, 10  (x, y)
    ## extent     : -180, 180, -90, 90  (xmin, xmax, ymin, ymax)
    ## crs        : +proj=longlat +datum=WGS84 +no_defs 
    ## source     : memory
    ## names      :   layer.1,   layer.2 
    ## min values : -3.008049, -3.008049 
    ## max values :  3.810277,  3.810277

### Importing and downloading data

The `raster()`, `stack()`, and `brick()` functions can not only be used
for creating `Raster*` objects from scratch, but also for reading raster
files from disk. To this end, we simply provide one or multiple file
paths instead of the names of the `R` objects.

Additionally, the `raster` package offers the interesting feature of
downloading data directly from a number of standard repositories with
the `getData()` function. For more information, see the help pages
?getData.

``` r
# Download RasterStack of global monthly minimum temperatures (°C*10)
tmin = getData("worldclim", var="tmin", res=10, download = T, path = "../data/") 
plot(tmin)
```

![](spatial_data_files/figure-gfm/unnamed-chunk-11-1.png)<!-- -->

## Manipulating Vector and Raster data

In the following section, we will look at some common operations on
spatial data.

### Attribute and spatial data operations

As we’ve seen above, we can manipulate the attribute data of `sf`
objects in the same way as non-spatial tabular data by using
`dplyr`-syntax, e.g. the `filter()`, `mutate()`, `select()`,
`summarise()`, and `arrange()` functions. The geometry column of `sf`
objects is *sticky* throughout attribute data operations, i.e. it is
always added back to the result. If we want to explicitly remove the
spatial context of the data, e.g. to speed up computations, we can use
the `st_drop_geometry()` function and convert our `sf` object to an
ordinary `data.frame`.

``` r
points_sf %>% 
  st_drop_geometry() %>% 
  class()
```

    ## [1] "data.frame"

Attribute data of raster objects behave similar to matrices in `R`. We
can do arithmetic operations (addition, subtraction, multiplication,
division), produce layer-wise summaries with the `cellStats()` function,
or calculate cell-wise summaries with the standard `min()`, `max()`, or
`mean()` functions. Both single- and multi-layer rasters can be subset
using familiar `[]`-syntax\`.

``` r
r1 + r1 # Arithmetic
```

    ## class      : RasterLayer 
    ## dimensions : 18, 36, 648  (nrow, ncol, ncell)
    ## resolution : 10, 10  (x, y)
    ## extent     : -180, 180, -90, 90  (xmin, xmax, ymin, ymax)
    ## crs        : +proj=longlat +datum=WGS84 +no_defs 
    ## source     : memory
    ## names      : layer 
    ## values     : -6.016097, 7.620553  (min, max)

``` r
cellStats(r1, min) # Minimum value per layer
```

    ## [1] -3.008049

``` r
min(stack(r1, r1/2)) # Minimum value per cell 
```

    ## class      : RasterLayer 
    ## dimensions : 18, 36, 648  (nrow, ncol, ncell)
    ## resolution : 10, 10  (x, y)
    ## extent     : -180, 180, -90, 90  (xmin, xmax, ymin, ymax)
    ## crs        : +proj=longlat +datum=WGS84 +no_defs 
    ## source     : memory
    ## names      : layer 
    ## values     : -3.008049, 1.905138  (min, max)

``` r
r1[7,13] # Subsetting
```

    ## [1] -0.331033

Instead of their attribute data, we can use the shape and location of
spatial objects to modify them. Since a complete coverage of spatial
data operations is beyond the scope of this workshop, we’ll just have a
look at one example. Here, we’ll use the `st_join()` function to join
country-level information from a simple polygon feature layer to our
`points_sf` object.

``` r
world_sf = ne_countries(returnclass = "sf") # Download country layer using rnaturalearth package
st_join(points_sf, world_sf) %>%  # join data based on location
  dplyr::select(point_name = name.x, country_name = name.y, population = pop_est) # select and rename results columns
```

    ## although coordinates are longitude/latitude, st_intersects assumes that they are planar
    ## although coordinates are longitude/latitude, st_intersects assumes that they are planar

    ## Simple feature collection with 20 features and 3 fields
    ## geometry type:  POINT
    ## dimension:      XY
    ## bbox:           xmin: -157.7569 ymin: -87.58974 xmax: 177.0862 ymax: 78.24694
    ## geographic CRS: WGS 84
    ## First 10 features:
    ##    point_name country_name population                    geometry
    ## 1           B       Canada   33487208  POINT (-84.41688 78.24694)
    ## 2           D         <NA>         NA  POINT (-46.0354 -51.81435)
    ## 3           D        Egypt   83082869   POINT (26.22721 27.30128)
    ## 4           D         <NA>         NA  POINT (146.9548 -67.40008)
    ## 5           B         <NA>         NA POINT (-107.3945 -41.90028)
    ## 6           D    Australia   21262641  POINT (143.4203 -20.49946)
    ## 7           A   Antarctica       3802  POINT (160.0831 -87.58974)
    ## 8           A         <NA>         NA  POINT (57.88721 -21.17017)
    ## 9           D       Russia  140041247   POINT (46.48106 66.54435)
    ## 10          A         <NA>         NA POINT (-157.7569 -28.73718)

### Geometry operations

### Raster-Vector operations

We can extract raster values for a set of point, line or polygon feature
with the `extract()` function.

``` r
extract(r1, points_sf) # Extract values of r1 at point coordinates defined by points_sf
extract(r1, lines_sf)  # Extract values of r1 across line transect defined by lines_sf
```

Subsetting a `Raster*` object to an area defined by a bounding box or
simple polygon feature is done using the `crop()` and `mask()`
functions, respectively.

## Some final notes
