install.packages("dismo")
library(dismo)

#load in covariate data
environmental_covariate_df <- read.csv("/Users/sagemcginley-smith/Desktop/mordecai_lab/sdm_project/climate_landuse_combined_Jan2023.csv")
# Set target species
target_species_vector <- c("Bichromomyia flaviscutellata")

#thinning a data set dataset for focal species 
{
  # Grab target species rows
  occ.target <- environmental_covariate_df %>%
    filter(scientificName %in% target_species_vector)
  # Clean lat long columns for thinning procedure
  occ_target_lat_lon <- as.data.frame(occ.target[,c("scientificName", "longitude", "latitude")])
  occ_target_lat_lon$latitude <- as.numeric(occ_target_lat_lon$latitude)
  occ_target_lat_lon$longitude <- as.numeric(occ_target_lat_lon$longitude)
  # Load raster to use for grid cell references
  rast <- raster("/Users/sagemcginley-smith/Desktop/mordecai_lab/sdm_project/1km_SA_raster.tif")
  # One point per grid cell
  s <- gridSample(occ_target_lat_lon[2:3], rast, n=1)
  thin.occ <- occ.target[row.names(s),]; thin.occ <- thin.occ[complete.cases(thin.occ), ]
  thin.occ$focal <- 1
  drop <- c("X")
  thin.occ <- thin.occ[,!(names(thin.occ) %in% drop)]
  write.csv(thin.occ, "/Users/sagemcginley-smith/Desktop/mordecai_lab/sdm_project/focal_species_thinned.csv")
  
}

#thinning data set for background species
# Grab all species excluding target
bg_df <- environmental_covariate_df %>%
  filter(!scientificName %in% c(target_species_vector, "", "sp."))
# Read in template raster
rast <- raster("/Users/sagemcginley-smith/Desktop/mordecai_lab/sdm_project/1km_SA_raster.tif")
### Extract number of background points per grid cell (i.e., weighted bias mask)
# Build as matrix with just lat long (cellFromXY function wants this format)
bg_points <- bg_df %>% dplyr::select(c(longitude, latitude)) %>%
  as.matrix()
# Add index
bg_df$index <- c(1:dim(bg_df)[1])
# Build data set that counts background points by grid cell to build background mask and outputs summary stats
#       about each grid cell grouping
bg_longlat <- cellFromXY(rast, bg_points) %>% as.data.frame() %>%
  #cbind(bg_df$year) %>%
  cbind(bg_df$index) %>%
  mutate(count = 1) %>% setNames(c("cell","index","count")) %>%
  group_by(cell) %>% dplyr::summarize(count = sum(count),
                                      max_index = max(index)) %>%
  arrange(desc(count)) %>%
  mutate(longitude = xFromCell(rast, cell),  # Acquire longitude (x) and latitude (y) from cell centroids
         latitude = yFromCell(rast, cell)) %>%
  dplyr::select(-cell) %>% # Cell number is now obsolete, since will be working from (x,y) as an sf object
  filter(!is.na(longitude) & !is.na(latitude)) # Remove the NA locations
# Build geometries (not sure you need this Sage but leaving just in case)
bg_mask_sf <- st_as_sf(bg_longlat, coords = c("longitude","latitude"),
                       agr = "constant", crs = 4326)
## Random sample bg without replacement from weighted bias mask at (1.5/2x occ) multiplier
# Set multiplier
multiplier <- 2
# Set seed so pulls the same each time if you rerun
set.seed(9)
# Calculate probabilities and add as column
bg_mask_weights <- bg_mask_sf %>%
  mutate(weight = count/sum(count))
bg_mask_df <- bg_mask_sf[sample(nrow(bg_mask_weights),
                                size = multiplier * nrow(thin.occ), #can replace thin.occ with whatever you’re calling your thinned occurrence point df
                                replace = FALSE, #without replacement
                                prob = bg_mask_weights$weight),]
# Link to environmental covariate data
bg_df_wcovariates <- cbind(bg_df[c(bg_mask_df$max_index),], bg_mask_df$geometry)

#remove columns and add the index value of 1
bg_df_wcovariates$focal <- 0
drop <- c("X", "index", "geometry")
bg_df_wcovariates <- bg_df_wcovariates[,!(names(bg_df_wcovariates) %in% drop)]

# export csv
write.csv(bg_df_wcovariates, "/Users/sagemcginley-smith/Desktop/mordecai_lab/sdm_project/background_species_thinned.csv")

# looking at counts of rows for different species
{
  counts <- table(thin.occ$scientificName)
  counts <- as.data.frame(counts)
  colnames(counts) <- c("species_name", "occurences_count")
  View(counts)
}


#joining background and focal species data
occ <- read.csv("/Users/sagemcginley-smith/Desktop/mordecai_lab/sdm_project/focal_species_thinned.csv")
background <- read.csv("/Users/sagemcginley-smith/Desktop/mordecai_lab/sdm_project/background_species_thinned.csv")
occ_background <- rbind(occ, background)
write.csv(occ_background, "/Users/sagemcginley-smith/Desktop/mordecai_lab/sdm_project/background_occurence_thinned.csv")

