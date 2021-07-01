Spatial data in R
================
Christian König & Damaris Zurell

**This practical exercise is a part of the workshop [Big Data
Ecology](https://github.com/ChrKoenig/Big_Data_Ecology)**

------------------------------------------------------------------------

## Introduction

Here, we focus on spatial data, a central data type in ecology.
Following the content of the lecture, we will work with vector and
raster data and perform a number of operations based on their attribute
data and spatial characteristics

We will use the following packages:

``` r
library(sf)
library(raster)
library(dplyr)
library(ggplot2)
```

If you haven’t installed them, please do so with the following command:

``` r
install.packages(c("dplyr", "sf", "raster", "ggplot2"))
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

The `sf` package provides a set of vector data classes and methods that
follow the *tidy* data model we already met in the *data base* unit. In
fact, the *simple feature* standard implemented by the `sf` is
language-independent and has been [adopted by many geospatial analysis
and database
platforms](https://en.wikipedia.org/wiki/Simple_Features#Implementations).

### Point features

Let’s create a set of random points to work with:

``` r
set.seed(1)
coords = data.frame(
  longitude = runif(n = 20, min = -180, max = 180),
  latitude = runif(n = 20, min = -90, max = 90)
)
plot(coords)
```

![](spatial_data_files/figure-gfm/unnamed-chunk-3-1.png)<!-- -->

Now we convert this coordinate data frame into a collection of spatial
points.

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

Next, we can add some attributes to `points_sf`. Since simple features
are essentially `data.frames` with a special column for the geometry of
the features, we can use the very same manipulation tools as for
non-spatial tidy data. To add a column (attribute), we use the
`mutate()` verb known from `dplyr`:

``` r
points_sf = points_sf %>% 
  mutate(name = sample(LETTERS[1:5], 20, replace = T))
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
holds multiple coordinate pairs to define the shape of the features.
Since it is cumbersome to create the geometry for line and polygon
features from scratch, we’ll simply confirm this statement aggregating
`points_sf` to one line feature per name.

``` r
lines_sf = points_sf %>% 
  group_by(name) %>%     # group by name
  filter(n() > 1) %>%    # lines need more than 1 point
  summarise(do_union = F) %>%  # Don't union geometries per group
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
`R`. The package contains different raster data classes, most important
for this course are `RasterLayer`, `RasterStack` and `RasterBrick`.
`RasterLayer` contain only a single layer of values while `RasterStack`
and `RasterBrick` can contain multiple layers (from separate files or
from a single multi-layer file, respectively).

### RasterLayers, RasterStacks and RasterBricks

The function `raster()` can be used to create RasterLayer objects.

``` r
r1 = raster(ncol=18, nrow=36, xmx=180, xmn=-180, ymx=90,  ymn=-90)
r1
```

    ## class      : RasterLayer 
    ## dimensions : 36, 18, 648  (nrow, ncol, ncell)
    ## resolution : 20, 5  (x, y)
    ## extent     : -180, 180, -90, 90  (xmin, xmax, ymin, ymax)
    ## crs        : +proj=longlat +datum=WGS84 +no_defs

We can access the attributes of each grid cell by using the function
`values()`. Since we set up an empty raster, there are no values yet in
the `RasterLayer` object and thus we assign some randomly.

``` r
values(r1) <- rnorm(ncell(r1)) # assign random values
plot(r1)   # plot raster
```

![](spatial_data_files/figure-gfm/unnamed-chunk-9-1.png)<!-- -->

`RasterStack` and `RasterBrick` objects can be created with the
`stack()` and `brick()` function, respectively.

``` r
# Copy r1 into new object
r2 = r1

# Stack the raster layers
stack(r1,r2)
```

    ## class      : RasterStack 
    ## dimensions : 36, 18, 648, 2  (nrow, ncol, ncell, nlayers)
    ## resolution : 20, 5  (x, y)
    ## extent     : -180, 180, -90, 90  (xmin, xmax, ymin, ymax)
    ## crs        : +proj=longlat +datum=WGS84 +no_defs 
    ## names      :   layer.1,   layer.2 
    ## min values : -3.008049, -3.008049 
    ## max values :  3.810277,  3.810277

``` r
brick(r1,r2)
```

    ## class      : RasterBrick 
    ## dimensions : 36, 18, 648, 2  (nrow, ncol, ncell, nlayers)
    ## resolution : 20, 5  (x, y)
    ## extent     : -180, 180, -90, 90  (xmin, xmax, ymin, ymax)
    ## crs        : +proj=longlat +datum=WGS84 +no_defs 
    ## source     : memory
    ## names      :   layer.1,   layer.2 
    ## min values : -3.008049, -3.008049 
    ## max values :  3.810277,  3.810277

### Reading in and downloading data

In addition to creating `Raster*` objects, the functions `raster()`,
`stack()`, and `brick()` can be used to read files from disk. For that,
we simply provide a file path to the raster file(s) instead of the names
of the `R` objects.

Additionally, `raster` offers the interesting feature of downloading
data directly from a number of standard repositories with the
`getData()` function. For more information, see the help pages ?getData.

``` r
# Download RasterStack of global monthly minimum temperatures
tmin = getData("worldclim", var="tmin", res=10) # Can also be saved to disc with download = T
plot(tmin)
```

![](spatial_data_files/figure-gfm/unnamed-chunk-11-1.png)<!-- -->

## Manipulating Vector and Raster data

In the following section, we will look at some common operations on
spatial data.

### Attribute data Operations

Attribute data operations in the `sf` package work . If we want to
convert an `sf` object, we can use the `drop_geometry` function. A nice
side effect of this is a considerable performance boost.

### Spatial data operations

Joining + Merge map algebra

### Geometry operations

Cropping Intersection Dissolve

Aggregate raster

### Raster-Vector operations

extract mask/crop

## Some final notes
