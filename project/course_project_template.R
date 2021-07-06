###            This script is part of the workshop Big Data Ecology          ###
# The sections of this course project are structured along the data life cycle 
# sensu Michener & Jones (2012). The project is complemented by a set of 
# lectures and practicals covering different aspects of Big Data Ecology.
# Check https://github.com/ChrKoenig/Big_Data_Ecology for more information  

# Fill the placeholders (<...>) across the script to develop the course project
# and find out more about the migration behaviour of Harrier species in Sweden!
#---------------------------------------------------------------------------- -#

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
gbif_id = taxize::get_gbifid(<...>) %>%  
  <...> 
  # --> Expectation: a character string of a 7-digit number
  
# Check number of georeferenced records in GBIF gbif_id in Sweden
n_occ = rgbif::occ_count(<...>)
# --> Expectation: a 6-digit number

# Download occurrence records
occ_download = rgbif::occ_data(<...>) # rgbif only allows to retrieve 500 occurrences
occs =  <...> 
occs_meta =  <...> 
  
# For larger queries, we need to write custom code or, better, use the GBIF download center:
# 1. Download full occurrence dataset
download.file("https://api.gbif.org/v1/occurrence/download/request/0294378-200613084148143.zip", destfile = "<...>")
occs = read_<...>(unzip("<...>"), <...>)

# 2. Download meta data
occs_meta = read_<...>("https://api.gbif.org/v1/occurrence/download/0294378-200613084148143/datasets/export?format=TSV", <...>)

#--------------------------------------------------------------------------------#
####                                  ASSURE                                  ####
#--------------------------------------------------------------------------------#
library(CoordinateCleaner)
library(skimr)

##### Check general dataset properties #####
# How many occurrences per species? (use dplyr)
species_n = <...>
# --> Expectation: A 5x2 tibble

# How many occurrences per dataset? (use dplyr)
datasets_n = <...>
# --> Expectation: A 9x2 tibble

# Compare dataset summary with occs_meta (use dplyr)
left_join(<...>) 

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
  drop_na(<...>) %>%  # Remove records with missing coordinates
  clean_coordinates(<...>)  # Run full check on coordinates
# --> What's the most common coordinate problem? Should we remove it?

# Create final occurrence dataset
occs_final = occs_cleaned %>% 
  filter(<...>,            # Remove flagged coordinates
         <...>,            # Remove coordinates without species name
         <...>) %>%        # Remove coordinates with uncertainty > 10000
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
# Find the following paper online:
# Storchová, L, Hořák, D. Life-history characteristics of European birds. Global Ecol Biogeogr. 2018; 27: 400– 406. https://doi.org/10.1111/geb.12709 
# Identify the repository where the associated data is stored and retrieve the URL of the data and metadata files 
download.file(url = "<...>", destfile = "<...>") # Data
download.file(url = "<...>", destfile = "<...>") # Metadata
traits  = read_<...>("<...>", <...>)
traits_meta = read_<...>("<...>", <...>)

# Extract migration behaviour of the different Circus species 
migration_behaviour = traits %>%       
  <...> %>%    # subset to Circus species
  <...>        # Select columns relevant to migration behaviours
# --> Expectation: A 4 x 4 tibble
# --> Which species has a different migration behaviour than the others?

##### Download Worldclim monthly layers for minimum temperature and precipitation at 10 arcmin resolution #####
tmin = <...> # 10 arc minutes raster
prec = <...> # 10 arc minutes raster
# --> Expectation: Two 900x2160x12 Raster Stacks

# Plot environmental layers
<...>
<...>

#--------------------------------------------------------------------------------#
####                                  INTEGRATE                               ####
#--------------------------------------------------------------------------------#
library(rnaturalearth)
library(raster)
library(sf)
library(parallel)

##### Convert occurrence data into spatial format #####
occs_st = sf::st_as_sf(<...>, crs = 4326)  
# --> Expectation: a 616244x59 simple feature point collection

##### Create a regular 0.5° grid across Sweden #####
sweden = ne_countries(<...>)
sweden_grid = sf::st_make_grid(<...>) %>% 
  sf::st_sf() %>% 
  rownames_to_column("grid_id")
# --> Expectation: a 423x2 simple feature polygon collection

##### Crop Environmental data to the Extent of Sweden #####
tmin_crop = <...>
prec_crop = <...>
# --> Expectation: two 87x79x12 Raster Bricks

##### Count occurrences per grid cell, month and species across sweden_grid #####
# 1. *Spatially* join sweden_grid and occs_st
grid_joined = <...> %>% 
  <...> 
# --> Expectation: a 568441x60 simple feature polygon collection

# 2. Count the number of records per grid cell, month, and species
grid_count = <...> %>% 
  st_drop_geometry() %>%      # speeds up computations
  group_by(<...>) %>% 
  summarize(<...>) %>% 
  ungroup() 
# --> Expectation: a 5345x4 tibble

# 3. Expand tibble to contain all possible combinations of grid_id, month and species
grid_count_cmpl = grid_count %>% 
  mutate(<...>) %>%    # convert month, species and grid_id to factor
  complete(<...>) %>%  # create all factor combinations
  mutate(<...>) %>%    # Set occurrence count of new combinations to 0
  <...>                # Remove rows that contain NA
# --> Expectation: a 203045x4 tibble

##### Extract environmental variables for each grid and month #####
# Test extraction for one env. variable for one month
system.time(raster::extract(<...>, <...>, fun = mean, <...>, df = T)) 
# ~6s runtime --> 6*12*2 = 144s expected total runtime

# Parallelize extraction
n_cores = <...> # Check available CPU cores
env_extract = <...>(<...>, function(month){
  tmin_tmp = extract(<...>)  # extract tmin
  prec_tmp = extract(<...>)  # extract prec 
  env_tmp  = <...>           # combine extracted values in data frame
  # --> Expectation: A 423x3 dataframe
  
  grid_env = <...> %>%  # Column-bind sweden_grid and env_tmp
    rename_with(~str_replace_all(.,"[:digit:]", "")) %>% # Remove numeric characters from column names
    <...>     # select grid_id, tmin, prec, month
}, mc.cores = <...>)
# --> Expectation: A list of 12 simple feature polygon collections with data columns grid_id, tmin, prec, month

# Combine list to single dataframe
env_extract_sf = <...>

#--------------------------------------------------------------------------------#
####                                   ANALYSE                                ####
#--------------------------------------------------------------------------------#
library(broom)
library(modelr)

##### Prepare final analysis table #####
# Merge env_extract_sf with grid_count_cmpl
data_final = <...> %>% 
  merge(<...>) %>%           # Merge dataframe env_extract_sf to attribute table of grid_count_cmpl
  mutate(present = <...>,    # Add a new column indicating presence/absence for a given species-cell-month combination
         month = <...>)      # convert month from factor to numeric
# --> Expectation: A 20304x7 simple feature polygon collection

##### Plot Data #####
# Boxplots of presence latitude per species and month
ggplot(occs_final, aes(x = <...>, y = <...>, fill = <...>, col = <...>)) +
  <...> +
  facet_wrap(<...>, nrow = 1) +
  theme_bw() +
  theme(axis.title.x=element_blank(),
        axis.text.x=element_blank(),
        axis.ticks.x=element_blank())

# Maps of geographical variation in abundance per species and month
ggplot(data_final, aes(fill = <...>)) +
  geom_sf(lwd = 0) +
  scale_fill_gradient(low = "blue", high = "red", trans = "log", breaks = c(1,10,100,1000,10000)) +
  facet_grid(rows = vars(<...>), cols = vars(<...>)) +
  theme(axis.text.x = element_text(angle=45, hjust=1)) +
  theme_bw()

# Maps of geographical variation in presence per species and month
ggplot(data_final, aes(fill = <...>)) +
  geom_sf(lwd = 0) +
  scale_fill_discrete() +
  facet_grid(rows = vars(<...>), cols = vars(<...>)) +
  theme(axis.text.x = element_text(angle=45, hjust=1)) +
  theme_bw()

##### Fit models #####
# Model Presence/Absence as a function of environmental variables (linear + squared terms)
specs = <...> # Unique species names
models = lapply(specs, function(spec){
  df_tmp = <...>  # Subset data_final to spec
  glm_tmp = glm(<...> ~ <...> + I(<...>^2) + <...> + I(<...>^2), family = <...>, data = <...>)  # Fit GLM
}) %>% setNames(<...>) # Name list elements after species
# --> Expectation: A list of four fitted GLMs (one per species) with appropriate link function

##### Plot environmental response #####
# Create evenly spaced 'grid' of environmental conditions
tmin_range = modelr::seq_range(range(<...>, na.rm = T), n = <...>)
prec_range = modelr::seq_range(range(<...>, na.rm = T), n = <...>)
var_grid = expand_grid(<...>)
# --> Expectation: A nx10000 matrix of evenly spaced combinations of tmin and prec

# Predict from fitted models to grid
pred_list = lapply(specs, function(spec){
  pred_tmp = predict(<...>, newdata = <...>, type = <...>)
  df_tmp = data.frame(<...>) %>% # create data frame with species name and predictions
    bind_cols(<...>)             # bind var_grid to current data frame
})
# --> Expectation: A list of model predictions for each species for var_grid 

# Create dataframe from pred_list
pred_df = <...>
  
# Plot heatmap of predicted occurrence probability under varying combinations of prec and tmin
ggplot(pred_df, aes(<...>)) +
  geom_contour_filled() +
  scale_color_viridis_c() +
  facet_wrap(<...>)         # make one plot per species

# How do species differ in their environmental response?
# Do our findings fit the information on migration behaviour? 

#--------------------------------------------------------------------------------#
####                                   PUBLISH                                ####
#--------------------------------------------------------------------------------#
# Go to https://odmap.wsl.ch/ and create an examplary ODMAP protocol of this course project 
# For more information on ODMAP, see Zurell et al. (2020) 10.1111/ecog.04960