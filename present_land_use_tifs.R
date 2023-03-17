library(raster)
library(rgdal)
library(sp)
library(sf)
library(dplyr)
library(tidyr)
library(rgdal)

##now read in lulc data and tack onto shape file
## read in the 1km grid for the amazon
base_sf <- st_read("/Users/sagemcginley-smith/Desktop/mordecai_lab/sdm_project/1km_grid_amazon/1km_grid_amazon.shp")

#csv from GEE for land use
lulc <- read.csv("/Users/sagemcginley-smith/Desktop/mordecai_lab/sdm_project/amazon_predictions_land_use_March2023.csv") 

######################
#clean lulc_int data
#removing any lulc that was not defined by classIDs in the MAPBIOMAS code 
lulc <- lulc[lulc$class != 0, ]
lulc$class[lulc$class == 3] <- "forest"
lulc$class[lulc$class == 11] <- "wetland"
lulc$class[lulc$class == 24] <- "urban"
lulc$class[lulc$class == 30] <- "mining"

{
  
  #----------------------------------------------------------#
  #go from wide to long so each class is a unique column     #
  #----------------------------------------------------------#
  
  mapbiomas_wide <- lulc[2:5] %>% 
    pivot_wider(names_from = class, 
                values_from = area,
                values_fn = list(area = sum),
                values_fill = list(area = 0)) 
  
  mapbiomas_mean_diff <- mapbiomas_wide %>%
    group_by(row_cod) %>%
    summarise(
      #mean per class
      mean_forest = mean(forest),
      mean_wetland = mean(wetland),
      mean_urban = mean(urban),
      mean_mining = mean(mining),
      #difference over study period per class
      diff_forest = forest[match(2020, year)] - forest[match(1985, year)],
      diff_wetland = wetland[match(2020, year)] - wetland[match(1985, year)],
      diff_urban = urban[match(2020, year)] - urban[match(1985, year)],
      diff_mining = mining[match(2020, year)] - mining[match(1985, year)])
  mapbiomas_mean_diff <- mapbiomas_mean_diff[complete.cases(mapbiomas_mean_diff),]
}

###then merge by row_id and create rasters
raster_df <- dplyr::left_join(base_sf, mapbiomas_mean_diff, by = 'row_cod') #lulc_wide, by = 'row_code')
raster_df <- na.omit(raster_df)
names(raster_df)[names(raster_df) == "row_cod"] <- "row_code"
##create rasters - template raster can be from any tif over the area of interest

#my_shapefile <- readOGR(dsn = "/Users/sagemcginley-smith/Desktop/mordecai_lab/sdm_project/1km_grid_amazon", layer = "1km_grid_amazon")

# create an empty raster with the same extent and resolution as the shapefile
#my_raster <- raster(ext = extent(my_shapefile), res = res(my_shapefile))

# rasterize the shapefile onto the empty raster
#my_rasterized <- rasterize(my_shapefile, my_raster)

# read in raster of amazon at 1 km (use one of the chelsea tifs)
template_raster <- raster("/Users/sagemcginley-smith/Desktop/mordecai_lab/sdm_project/tif_files/chelsa_bio5.tif")
grid = stars::st_as_stars(st_bbox(template_raster), dx = 0.008983153, dy = 0.008983153)

mean_forest <- stars::st_rasterize(raster_df[,"mean_forest"], grid, align = TRUE, file = "mean_forest.tif", driver = "GTiff")
diff_forest <- stars::st_rasterize(raster_df[,"diff_forest"], grid, align = TRUE, file = "diff_forest.tif", driver = "GTiff")
mean_wetland <- stars::st_rasterize(raster_df[,"mean_wetland"], grid, align = TRUE, file = "mean_wetland.tif", driver = "GTiff")
diff_wetland <- stars::st_rasterize(raster_df[,"diff_wetland"], grid, align = TRUE, file = "diff_wetland.tif", driver = "GTiff")
mean_urban <- stars::st_rasterize(raster_df[,"mean_urban"], grid, align = TRUE, file = "mean_urban.tif", driver = "GTiff")
diff_urban <- stars::st_rasterize(raster_df[,"diff_urban"], grid, align = TRUE, file = "diff_urban.tif", driver = "GTiff")
mean_mining <- stars::st_rasterize(raster_df[,"mean_mining"], grid, align = TRUE, file = "mean_mining.tif", driver = "GTiff")
diff_mining <- stars::st_rasterize(raster_df[,"diff_mining"], grid, align = TRUE, file = "diff_mining.tif", driver = "GTiff")
