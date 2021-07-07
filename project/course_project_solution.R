###              This script is part of the workshop Big Data Ecology          ###
# The sections of this course project are structured along the data life cycle 
# sensu Michener & Jones (2012). The project is complemented by a set of 
# lectures and practicals covering different aspects of Big Data Ecology.
# Check https://github.com/ChrKoenig/Big_Data_Ecology for more information  
#--------------------------------------------------------------------------------#

#--------------------------------------------------------------------------------#
####                                    PLAN                                  ####
#--------------------------------------------------------------------------------#
# - Re-read the course project description and data management plan laid out in the main lecture
# - Follow the code examples and instructions from the version control practical to set up 
#   a git repository for your course project
# - Verify that your project is under version control by checking whether the 'git' icon in the
#   RStudio toolbar is enabled

#--------------------------------------------------------------------------------#
####                                  COLLECT                                 ####
#--------------------------------------------------------------------------------#
library(tidyverse)
library(taxize)
library(rgbif)

# Find gbif_ID for 'Circus Lacepede 1799'
gbif_id = taxize::get_gbifid("Circus", rank = "Genus") %>% as.character() # Take the first one
# --> Expectation: a character string of a 7-digit number

# Check number of georeferenced records in GBIF
n_occ = rgbif::occ_count(taxonKey = gbif_id, georeferenced = T, country = "SE")
# --> Expectation: a 6-digit number

# Download occurrence records
occ_download = rgbif::occ_data(taxonKey = gbif_id, hasCoordinate = T, country = "SE") # rgbif only allows to retrieve 500 occurrences
occs = occ_download$data
occs_meta = occ_download$meta

# For larger queries, we need to write custom code or, better, use the GBIF download center:
# 1. Download full occurrence dataset
download.file("https://api.gbif.org/v1/occurrence/download/request/0294378-200613084148143.zip", destfile = "data/occs_circus.zip")
occs = read_delim(unzip("data/occs_circus.zip"), delim = "\t", quote = "")

# 2. Download meta data
occs_meta = read_delim("https://api.gbif.org/v1/occurrence/download/0294378-200613084148143/datasets/export?format=TSV", delim = "\t", quote = "")

#--------------------------------------------------------------------------------#
####                                  ASSURE                                  ####
#--------------------------------------------------------------------------------#
library(CoordinateCleaner)
library(skimr)

##### Check general dataset properties #####
# How many occurrences per species? (use dplyr)
species_n = occs %>% group_by(species) %>% tally() 
# --> Expectation: A 5x2 tibble

# How many occurrences per dataset? (use dplyr)
datasets_n = occs %>% group_by(datasetKey) %>% tally() 
# --> Expectation: A 9x2 tibble

# Compare dataset summary with occs_meta (use dplyr)
left_join(occs_meta, datasets_n, by = c("dataset_key" = "datasetKey")) 

# Was the data download and import successful?
# Are there discrepancies between official metadata and dataset summary?
# If the numbers don't match, go back to the code where you read the tab-delimited file from the .zip-file
# and add  'quote = ""' to the read_delim function. What may have been the problem?

##### Check occurrence data #####
# Plot data
ggplot(occs, aes(x = decimalLongitude, y = decimalLatitude)) +
  borders(database = "world", regions = "Sweden") +
  stat_bin_hex() +
  scale_fill_gradient(low = "blue", high = "red", trans = "log",  breaks = c(1,10,100,1000,10000)) +
  facet_wrap("species")
# --> What problem is apparent immediately? Are there any other obvious inconsistencies?

# Check for geographical inconsistencies and other common problems
occs_cleaned = occs %>% 
  drop_na("decimalLongitude", "decimalLatitude") %>% 
  clean_coordinates(lon = "decimalLongitude", lat = "decimalLatitude")
# --> What's the most common coordinate problem? Should we remove it?

# Create final occurrence dataset
occs_final = occs_cleaned %>% 
  filter(.summary == TRUE,              # Remove flagged coordinates
         !is.na(species),               # Remove coordinates without species name
         coordinateUncertaintyInMeters < 10000) %>% # Remove coordinates with uncertainty > 10000
  as_tibble()
# --> Expectation: a 616244x60 tibble

# Create informative summary of final occurrence table
skim(occs_final)

# Check if there is a temporal pattern in the data
ggplot(occs_final, aes(x = decimalLongitude, y = decimalLatitude)) +
  borders(database = "world", regions = "Sweden") +
  stat_bin_hex() +
  scale_fill_gradient(low = "blue", high = "red", trans = "log", breaks = c(1,10,100,1000,10000)) +
  facet_wrap("month")

#--------------------------------------------------------------------------------#
####                        DESCRIBE / SUBMIT / PRESERVE                      ####
#--------------------------------------------------------------------------------#
# Not applicable

#--------------------------------------------------------------------------------#
####                                  DISCOVER                                ####
#--------------------------------------------------------------------------------#
library(raster)

##### Download trait data #####
download.file("https://datadryad.org/stash/downloads/file_stream/32736", destfile = "data/traits.txt")
download.file("https://datadryad.org/stash/downloads/file_stream/32737", destfile = "data/traits_meta.txt")
traits  = read_delim("data/traits.txt", delim = "\t", quote = "")
traits_meta = read_csv("data/traits_meta.txt", quote = "")

# Extract migration behaviour of the different Circus species 
colnames(traits) # inspect column names
migration_behaviour = traits %>%       # subset data
  dplyr::filter(str_detect(Species, "Circus")) %>% 
  dplyr::select(Species, contains("migr"))
# --> Expectation: A 4 x 4 tibble
# --> Which species has a different migration behaviour than the others?

##### Download Worldclim monthly layers for minimum temperature and precipitation at 10 arcmin resolution #####
tmin = raster::getData("worldclim", var = "tmin", res = 10, path = "data/") # 10 arc minutes
prec = raster::getData("worldclim", var = "prec", res = 10, path = "data/") # 10 arc minutes
# --> Expectation: Two 900x2160x12 Raster Stacks

# Plot environmental layers
plot(tmin)
plot(prec)

#--------------------------------------------------------------------------------#
####                                  INTEGRATE                               ####
#--------------------------------------------------------------------------------#
library(rnaturalearth)
library(raster)
library(sf)
library(parallel)

##### Convert occurrence data into spatial format #####
occs_st = sf::st_as_sf(occs_final, coords = c("decimalLongitude", "decimalLatitude"), crs = 4326)  
# --> Expectation: a 616244x59 simple feature point collection

##### Create a regular 0.5° grid across Sweden #####
sweden = ne_countries(country = "Sweden", returnclass = "sf")
sweden_grid = sf::st_make_grid(sweden, cellsize = 0.5, square = F) %>% 
  sf::st_sf() %>% 
  rownames_to_column("grid_id")
# --> Expectation: a 423x2 simple feature polygon collection

##### Crop Environmental data to the Extent of Sweden #####
tmin_crop = raster::crop(tmin, sweden)
prec_crop = raster::crop(prec, sweden)
# --> Expectation: two 87x79x12 Raster Bricks

##### Count occurrences per grid cell, month and species across sweden_grid #####
# 1. *Spatially* join sweden_grid and occs_st
grid_joined = sweden_grid %>% 
  st_join(occs_st) 
# --> Expectation: a 568441x60 simple feature polygon collection

# 2. Count the number of records per grid cell, month, and species
grid_count = grid_joined %>% 
  st_drop_geometry() %>%      # speeds up computations
  group_by(grid_id, month, species) %>% 
  summarize(n_occ = n()) %>% 
  ungroup() 
# --> Expectation: a 5345x4 tibble

# 3. Expand tibble to contain all possible combinations of grid_id, month and species
#    Set occurrence count of new combinations to 0
grid_count_cmpl = grid_count %>% 
  mutate(month = as.factor(month), species = as.factor(species), grid_id = as.factor(grid_id)) %>% 
  complete(grid_id, month, species) %>% 
  mutate(n_occ = replace_na(n_occ, 0)) %>% 
  drop_na()
# --> Expectation: a 203045x4 tibble

##### Extract environmental variables for each grid and month #####
# Test extraction for one env. variable for one month
system.time(extract(tmin_crop[[1]], sweden_grid, fun = mean, na.rm = T, df = T)) 
# ~6s runtime --> 6*12*2 = 144s expected total runtime

# Parallelize extraction
n_cores = detectCores()
env_extract = mclapply(1:12, function(month){   # TODO: This didn't work on Windows machines, adapt to foreach + doPar instead?
  tmin_tmp = extract(tmin_crop[[month]], sweden_grid, fun = mean, na.rm = T, cellnumbers = F, df = T)
  prec_tmp = extract(prec_crop[[month]], sweden_grid, fun = mean, na.rm = T, cellnumbers = F, df = T)
  env_tmp  = full_join(tmin_tmp, prec_tmp) 
  grid_env = bind_cols(sweden_grid, env_tmp) %>% 
    dplyr::mutate(month = month) %>% 
    rename_with(~str_replace_all(.,"[:digit:]", "")) %>% 
    dplyr::select(grid_id, tmin, prec, month)
}, mc.cores = n_cores)
# --> Expectation: A list of 12 simple feature polygon collections with data columns grid_id, tmin, prec, month

# Combine list to single dataframe
env_extract_sf = bind_rows(env_extract)

#--------------------------------------------------------------------------------#
####                                   ANALYSE                                ####
#--------------------------------------------------------------------------------#
library(broom)
library(modelr)

##### Prepare final analysis table #####
# Merge env_extract_sf with grid_count_cmpl
# Add a new column indicating presence/absence for a given species-cell-month combination
data_final = env_extract_sf %>% 
  merge(grid_count_cmpl) %>% 
  mutate(present = as.numeric(n_occ > 0),
         month = as.numeric(month))
# --> Expectation: A 20304x7 simple feature polygon collection

##### Plot Data #####
# Boxplots of presence latitude per species and month
ggplot(occs_final, aes(x = species, y = decimalLatitude, fill = species, col = species)) +
  geom_boxplot() +
  facet_wrap("month", nrow = 1) +
  theme_bw() +
  theme(axis.title.x=element_blank(),
        axis.text.x=element_blank(),
        axis.ticks.x=element_blank())

# Maps of geographical variation in abundance per species and month
ggplot(data_final, aes(fill = n_occ)) +
  geom_sf(lwd = 0) +
  scale_fill_gradient(low = "blue", high = "red", trans = "log", breaks = c(1,10,100,1000,10000)) +
  facet_grid(rows = vars(species), cols = vars(month)) +
  theme(axis.text.x = element_text(angle=45, hjust=1)) +
  theme_bw()

# Maps of geographical variation in presence per species and month
ggplot(data_final, aes(fill = as.factor(present))) +
  geom_sf(lwd = 0) +
  scale_fill_discrete() +
  facet_grid(rows = vars(species), cols = vars(month)) +
  theme(axis.text.x = element_text(angle=45, hjust=1)) +
  theme_bw()

##### Fit models #####
# Model Presence/Absence as a function of environmental variables (linear + squared terms)
specs = unique(data_final$species)
models = lapply(specs, function(spec){
  df_tmp = filter(data_final, species == spec)
  glm_tmp = glm(present ~ tmin + I(tmin^2) + prec + I(prec^2), family = "binomial", data = df_tmp)
}) %>% setNames(specs)
# --> Expectation: A list of four fitted GLMs (one per species) with appropriate link function

##### Plot environmental response #####
# Create evenly spaced 'grid' of environmental conditions
tmin_range = modelr::seq_range(range(env_extract_sf$tmin, na.rm = T), n = 100)
prec_range = modelr::seq_range(range(env_extract_sf$prec, na.rm = T), n = 100)
var_grid = expand_grid(tmin = tmin_range, prec = prec_range)
# --> Expectation: A nx2 matrix of evenly spaced combinations of tmin and prec

# Predict from fitted models to grid
pred_list = lapply(specs, function(spec){
  pred_tmp = predict(models[[spec]], newdata = var_grid, type = "response")
  df_tmp = data.frame(species = spec, pred = pred_tmp) %>% 
    bind_cols(var_grid)
})
# --> Expectation: A list of model predictions for each species for var_grid 

# Create dataframe from pred_list
pred_df = bind_rows(pred_list)

# Plot predicted presence probability under varying combinations of prec and tmin
ggplot(pred_df, aes(x = tmin, y = prec, z = pred, color = pred)) +
  geom_contour_filled() +
  scale_color_viridis_c() +
  facet_wrap("species")

#--------------------------------------------------------------------------------#
####                                   PUBLISH                                ####
#--------------------------------------------------------------------------------#
# Go to https://odmap.wsl.ch/ and create an ODMAP protocol of this course project 
# For more information on ODMAP, see Zurell et al. (2020) 10.1111/ecog.04960