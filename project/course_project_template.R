library(rgbif)
library(ridigbio)
library(taxize)
library(rdryad)
library(tidyverse)
library(skimr)
library(CoordinateCleaner)
library(sf)
library(raster)
library(rnaturalearth)

rm(list = ls())
setwd("~/ownCloud/Projects/Berlin/11_Ecological_data_workshop/")

# 1 Set up project and GIT
#
#

# COLLECT
# 2 Download occurrence data
gbif_id = taxize::get_gbifid("Circus", rank = "Genus") %>% # Type '1' for Circus Lacepede 1799
  as.character() # Take the first one

n_occ = rgbif::occ_count(taxonKey = gbif_id, georeferenced = T, country = "SE")
occ_download = rgbif::occ_data(taxonKey = gbif_id, hasCoordinate = T, country = "SE")
occs = occ_download$data
occs_meta = occ_download$meta

# Only 500 occurrences, for larger queries we need to write custom code or (better:) use the GBIF download center
occs = read_delim("Data/Circus_dl_simple/0294378-200613084148143.csv", delim = "\t")
occs_meta = read_delim("Data/Circus_dl_simple/datasets_download_usage_0294378-200613084148143.tsv", delim = "\t")

# Exercise: How many occurrences per species?
species_n = occs %>% group_by(species) %>% tally() 

# Exercise: How many occurrences per dataset
datasets = occs %>% dplyr::select(datasetKey) %>% distinct()
datasets_n = occs %>% group_by(datasetKey) %>% tally() 
summary_comparison = left_join(occs_meta, datasets_n) # Why the discrepancy?

occs = read_delim("Data/Circus_dl_simple/0294378-200613084148143.csv", delim = "\t", quote = "")
# --> redo check

# Plot
ggplot(occs, aes(x = decimalLongitude, y = decimalLatitude)) +
  borders(database = "world", regions = "Sweden") +
  stat_bin_hex() +
  scale_fill_gradient(low = "blue", high = "red", trans = "log",  breaks = c(1,10,100,1000,10000)) +
  facet_wrap("species")

# Geographical outliers?
# NA species?
# NA lon/lat?
# CoordinateUncertainty?

# What additional problems --> Use CoordinateCleaner
occs_cleaned = occs %>% drop_na(decimalLongitude, decimalLatitude) %>% 
  clean_coordinates(lon = "decimalLongitude", lat = "decimalLatitude")
# What's the most common coordinate problem? Remove?
ggplot(occs_cleaned, aes(x = decimalLongitude, y = decimalLatitude, color = .sea)) +
  borders(database = "world", regions = "Sweden") +
  geom_point()

# Final occurrence dataset
occs_final = occs_cleaned %>% 
  filter(.summary == TRUE, !is.na(species), coordinateUncertaintyInMeters < 10000)

skim(occs_final)

# DISCOVER
# Download trait data
dryad_dataset  = rdryad::dryad_dataset("10.5061/dryad.n6k3n")[[1]]
dryad_download = rdryad::dryad_download("10.5061/dryad.n6k3n")[[1]]
traits = read_delim(dryad_download[1], delim = "\t", quote = "")
traits_meta = read_delim(dryad_download[2], delim = "\t", quote = "")

# Exercise: Find out the migration behaviour of the different circus species
colnames(traits) # inspect column names
migration_behaviour = traits %>%       # subset data
  dplyr::filter(str_detect(Species, "Circus")) %>% 
  dplyr::select(Species, contains("migr"))
# Expectation: A table 4x4 table with migraiton behaviour for the four considered species

# Look at monthly distribution
ggplot(filter(occs_final, species == "Circus aeruginosus"), aes(x = decimalLongitude, y = decimalLatitude)) +
  borders(database = "world", regions = "Sweden") +
  stat_bin_hex() +
  scale_fill_gradient(low = "blue", high = "red", trans = "log", breaks = c(1,10,100,1000,10000)) +
  facet_wrap("month")

ggplot(filter(occs_final, species == "Circus cyaneus"), aes(x = decimalLongitude, y = decimalLatitude)) +
  borders(database = "world", regions = "Sweden") +
  stat_bin_hex() +
  scale_fill_gradient(low = "blue", high = "red", trans = "log", breaks = c(1,10,100,1000,10000)) +
  facet_wrap("month")

ggplot(filter(occs_final, species == "Circus pygargus"), aes(x = decimalLongitude, y = decimalLatitude)) +
  borders(database = "world", regions = "Sweden") +
  geom_point(size = 0.1) +
  scale_fill_gradient(low = "blue", high = "red", trans = "log", breaks = c(1,10,100,1000,10000)) +
  facet_wrap("month")

ggplot(filter(occs_final, species == "Circus macrourus"), aes(x = decimalLongitude, y = decimalLatitude)) +
  borders(database = "world", regions = "Sweden") +
  geom_point(size = 0.1) +
  scale_fill_gradient(low = "blue", high = "red", trans = "log", breaks = c(1,10,100,1000,10000)) +
  facet_wrap("month")

ggplot(occs_final, aes(x = as.factor(month), y = decimalLatitude)) +
  geom_boxplot() +
  facet_wrap("species")


# Count species per month and grid
sweden = ne_countries(country = "Sweden", returnclass = "sf")
sweden_grid = st_make_grid(sweden, cellsize = 0.5, square = F) %>% 
  st_sf() %>% 
  rownames_to_column("grid_id")

occs_st = st_as_sf(occs_final, coords = c("decimalLongitude", "decimalLatitude"), crs = 4326)  

grid_count = sweden_grid %>% 
  st_join(occs_st) %>% 
  st_drop_geometry() %>% 
  group_by(grid_id, month, species) %>% 
  summarize(n_occ = n()) %>% 
  ungroup() %>% 
  mutate(month = as.factor(month), species = as.factor(species), grid_id = as.factor(grid_id)) %>% 
  complete(grid_id, month, species) %>% 
  mutate(n_occ = replace_na(n_occ, 0)) %>% 
  drop_na()

grid_count_final = sweden_grid %>% 
  merge(grid_count, by = "grid_id")

# Grid plots for all species
ggplot(grid_count_final, aes(fill = n_occ)) +
  geom_sf(lwd = 0) +
  scale_fill_gradient(low = "blue", high = "red", trans = "log", breaks = c(1,10,100,1000,10000)) +
  facet_grid(rows = vars(species), cols = vars(month)) +
  theme(axis.text.x = element_text(angle=45, hjust=1)) +
  theme_bw()

# Extract climate variables 
tmin = raster::getData("worldclim", var = "tmin", res = 10, path = "Data/") # 10 arc minutes
prec = raster::getData("worldclim", var = "prec", res = 10, path = "Data/") # 10 arc minutes

dim(tmin) # One layer per month
dim(prec)

# Crop to study extent
tmin_crop = crop(tmin, sweden_grid)
prec_crop = crop(prec, sweden_grid)

# Test environmental extraction
m = 1 # January
grid_jan = dplyr::filter(grid_count_final, month == m)
tmin_jan = extract(tmin_crop[[m]], grid_jan, fun = mean, na.rm = T, df = T) # Takes a while --> parallelize

# Extract environmental variables for raster+month combinations
library(parallel)
n_cores = detectCores()-1

env_extract = mclapply(1:12, FUN = function(m){
  # Split apply combine
  # What is a good variable to split the data (month: yes, species: not really because redunant)
  grid_tmp = dplyr::filter(grid_count_final, month == m)
  tmin_tmp = extract(tmin_crop[[m]], grid_tmp, fun = mean, na.rm = T, cellnumbers = F, df = T)
  prec_tmp = extract(prec_crop[[m]], grid_tmp, fun = mean, na.rm = T, df = T)
  env_tmp  = full_join(tmin_tmp, prec_tmp) 
  grid_env = bind_cols(grid_tmp, env_tmp) %>% 
    dplyr::select(-ID) %>% 
    rename_with(~str_replace_all(.,"[:digit:]", ""))
}, mc.cores = n_cores)

env_extract_sf = bind_rows(env_extract)
ggplot(env_extract_sf, aes(fill = prec)) +
  geom_sf(lwd = 0) +
  scale_fill_gradient(low = "blue", high = "red") +
  facet_wrap(vars(month)) +
  theme(axis.text.x = element_text(angle=45, hjust=1)) +
  theme_bw()

ggplot(env_extract_sf, aes(fill = tmin)) +
  geom_sf(lwd = 0) +
  scale_fill_gradient(low = "blue", high = "red") +
  facet_wrap(vars(month)) +
  theme(axis.text.x = element_text(angle=45, hjust=1)) +
  theme_bw()

# fit poisson model
plot(n_occ ~ tmin, data = env_extract_sf)
plot(n_occ ~ prec, data = env_extract_sf)

# TODO: replace with binary models 
# richness_CirAer = glm(n_occ ~ tmin + I(tmin^2) + prec + I(prec^2), family = "poisson",
#                     data = filter(env_extract_sf, species == "Circus aeruginosus"))
# richness_CirCya = glm(n_occ ~ tmin + I(tmin^2) + prec + I(prec^2), family = "poisson",
#                       data = filter(env_extract_sf, species == "Circus cyaneus"))
# richness_CirMac = glm(n_occ ~ tmin + I(tmin^2) + prec + I(prec^2), family = "poisson",
#                       data = filter(env_extract_sf, species == "Circus macrourus"))
# richness_CirPyg = glm(n_occ ~ tmin + I(tmin^2) + prec + I(prec^2), family = "poisson",
#                       data = filter(env_extract_sf, species == "Circus pygargus"))

# Plot response
library(modelr)
tmin_range = seq_range(range(env_extract_sf$tmin, na.rm = T), n = 100)
prec_range = seq_range(range(env_extract_sf$prec, na.rm = T), n = 100)
var_grid = expand_grid(tmin = tmin_range, prec = prec_range)
pred = predict(richness_CirAer, newdata = var_grid, type = "response")

df_plot = bind_cols(var_grid, pred = log10(pred))
ggplot(df_plot, aes(x = tmin, y = prec, z = pred, color = pred)) +
  geom_contour_filled() +
  scale_color_viridis_c()
