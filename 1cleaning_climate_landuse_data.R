###cleaning mapbiomas data for SDM

#install and load packages
{install.packages(c("tidyr", "dplyr", "PerformanceAnalytics", "spatialsample", "sf", "stats", "tidyverse", "ggplot2"))
  library(tidyr); library(dplyr); library(PerformanceAnalytics); library(spatialsample); library(sf); library(stats); library(tidyverse); library(ggplot2)
}


#read in datasets 
{mapbiomas <- read.csv("/Users/sagemcginley-smith/Desktop/mordecai_lab/sdm_project/sandfly_land_cover_brazil_Jan2023.csv")
  climate <- read.csv("/Users/sagemcginley-smith/Desktop/mordecai_lab/sdm_project/chelsea_data_Jan2023.csv")
  vectors <- read.csv("/Users/sagemcginley-smith/Desktop/mordecai_lab/sdm_project/sandfly_vectors_renamed.csv")}

#---------------------------------------#
#update label for MAPBIOMAS classes     #
#---------------------------------------#

#checking which classes were included in the data set
unique(mapbiomas$class)

#relabel each class to make it easier to see results
{
  mapbiomas$class[mapbiomas$class == 3] <- "forest_formation"
  mapbiomas$class[mapbiomas$class == 14] <- "farming"
  mapbiomas$class[mapbiomas$class == 4] <- "savanna_formation"
  mapbiomas$class[mapbiomas$class == 11] <- "wetland"
  mapbiomas$class[mapbiomas$class == 12] <- "grassland"
  mapbiomas$class[mapbiomas$class == 24] <- "urban_infrastructure"
  mapbiomas$class[mapbiomas$class == 6] <- "flooded_forest"
  mapbiomas$class[mapbiomas$class == 30] <- "mining"
  mapbiomas$class[mapbiomas$class == 5] <- "mangrove"
  mapbiomas$class[mapbiomas$class == 27] <- "not_observed"
}

#flattening and cleaning up land use data
{#removing any lulc that was not defined by classIDs in the MAPBIOMAS code 
  mapbiomas <- mapbiomas[mapbiomas$class != 0, ]
  
  #----------------------------------------------------------#
  #go from wide to long so each class is a unique column     #
  #----------------------------------------------------------#
  
  mapbiomas_wide <- mapbiomas[2:5] %>% 
    pivot_wider(names_from = class, 
                values_from = area,
                values_fn = list(area = sum),
                values_fill = list(area = 0)) 
  
  mapbiomas_mean_diff <- mapbiomas_wide %>%
    group_by(row_identifier) %>%
    summarise(
      #mean per class
      mean_forest = mean(forest_formation),
      #mean_farming = mean(farming),
      mean_savanna = mean(savanna_formation),
      mean_wetland = mean(wetland),
      mean_grassland = mean(grassland),
      mean_urban_infrastructure = mean(urban_infrastructure),
      #mean_flooded_forest = mean(flooded_forest),
      mean_mining = mean(mining),
      mean_mangrove = mean(mangrove),
      #mean_not_observed = mean(not_observed),
      
      #difference over study period per class
      diff_forest = forest_formation[match(2020, year)] - forest_formation[match(2001, year)],
      #diff_farming = farming[match(2020, year)] - farming[match(2001, year)],
      diff_savanna = savanna_formation[match(2020, year)] - savanna_formation[match(2001, year)],
      diff_wetland = wetland[match(2020, year)] - wetland[match(2001, year)],
      diff_grassland = grassland[match(2020, year)] - grassland[match(2001, year)],
      diff_urban_infrastructure = urban_infrastructure[match(2020, year)] - urban_infrastructure[match(2001, year)],
      #diff_flooded_forest = flooded_forest[match(2020, year)] - flooded_forest[match(2001, year)],
      diff_mining = mining[match(2020, year)] - mining[match(2001, year)],
      diff_mangrove = mangrove[match(2020, year)] - mangrove[match(2001, year)])
      #diff_not_observed = not_observed[match(2020, year)] - not_observed[match(2001, year)])
  
  #remove any incomplete cases that came out of the differencing
  mapbiomas_mean_diff <- mapbiomas_mean_diff[complete.cases(mapbiomas_mean_diff),]
}

#save dataframe
write.csv(mapbiomas_mean_diff, "/Users/sagemcginley-smith/Desktop/mordecai_lab/sdm_project/mapbiomas_cleaned_brazil_Jan2023.csv")

#----------------------------------------------------------#
#cleaning up the climate data                              #
#----------------------------------------------------------#

for ( col in 1:ncol(climate)){
  colnames(climate)[col] <-  sub("_b1*", "", colnames(climate)[col])
}

#remove unecessary heads
climate = subset(climate, select = -c(system.index) )

#move row_identifier and scientific name of data points to the first two columns 
climate <- climate %>%
  select(row_identifier, scientificName, everything())

#adjusting the values for temp and and precip to be celcius and mm, respectively
{climate$bio1 <- (climate$bio1*0.1) - 273.15
  climate$bio2 <- climate$bio2 * 0.1
  climate$bio3 <- climate$bio3 * 0.1
  climate$bio4 <- climate$bio4 * 0.1
  climate$bio5 <- (climate$bio5*0.1) - 273.15
  climate$bio6 <- (climate$bio6*0.1) - 273.15
  #climate$bio7 <- climate$bio7 * 0.1
  #climate$bio8 <- (climate$bio8 * 0.1) - 273.15
  climate$bio9 <- (climate$bio9 * 0.1) - 273.15
  climate$bio10 <- (climate$bio10 * 0.1) - 273.15
  #climate$bio11 <- (climate$bio11 * 0.1) - 273.15
  climate$bio12 <- climate$bio12 * 0.1
  climate$bio13 <- climate$bio13 * 0.1
  climate$bio14 <- climate$bio14 * 0.1
  climate$bio15 <- climate$bio15 * 0.1
  climate$bio16 <- climate$bio16 * 0.1
  climate$bio17 <- climate$bio17 * 0.1
  climate$bio18 <- climate$bio18 * 0.1
  climate$bio19 <- climate$bio19 * 0.1
  }

#save dataframe
write.csv(climate, "/Users/sagemcginley-smith/Desktop/mordecai_lab/sdm_project/climate_cleaned_Jan2023.csv")

amazon <- read.csv("/Users/sagemcginley-smith/Desktop/mordecai_lab/sdm_project/mapbiomas_cleaned_amazon_Jan2023.csv")
brazil <- read.csv("/Users/sagemcginley-smith/Desktop/mordecai_lab/sdm_project/mapbiomas_cleaned_brazil_Jan2023.csv")

land_use_all <- merge(amazon, brazil, by = "row_identifier", all = TRUE)

#merging sheets
final <- list(vectors,land_use_all,climate) %>% reduce(inner_join, by='row_identifier')
drop <- c(".geo","scientificName.y", "X.x", "X.y", "mean_flooded_forest", 
          "diff_flooded_forest", "mean_farming", "mean_not_observed")
final <- final[,!(names(final) %in% drop)]
final <- final %>% 
  rename("scientificName" = "scientificName.x")
for (i in 1:nrow(final)) {
  final[i, "mean_forest_combined"] = mean(c(final[i,"mean_forest.x"], final[i,"mean_forest.y"]), na.rm = TRUE)
  #final[i, "mean_farming_combined"] = mean(c(final[i,"mean_farming.x"], final[i,"mean_farming.y"]), na.rm = TRUE)
  final[i, "mean_savanna_combined"] = mean(c(final[i,"mean_savanna.x"], final[i,"mean_savanna.y"]), na.rm = TRUE)
  final[i, "mean_wetland_combined"] = mean(c(final[i,"mean_wetland.x"], final[i,"mean_wetland.y"]), na.rm = TRUE)
  final[i, "mean_grassland_combined"] = mean(c(final[i,"mean_grassland.x"], final[i,"mean_grassland.y"]), na.rm = TRUE)
  final[i, "mean_urban_combined"] = mean(c(final[i,"mean_urban_infrastructure.x"], final[i,"mean_urban_infrastructure.y"]), na.rm = TRUE)
  final[i, "mean_mining_combined"] = mean(c(final[i,"mean_mining.x"], final[i,"mean_mining.y"]), na.rm = TRUE)
  final[i, "mean_mangrove_combined"] = mean(c(final[i,"mean_mangrove.x"], final[i,"mean_mangrove.y"]), na.rm = TRUE)
  #final[i, "mean_not_observed_combined"] = mean(c(final[i,"mean_not_observed.x"], final[i,"mean_not_observed.y"]), na.rm = TRUE)
  final[i, "diff_forest_combined"] = mean(c(final[i,"diff_forest.x"], final[i,"diff_forest.y"]), na.rm = TRUE)
  #final[i, "diff_farming_combined"] = mean(c(final[i,"diff_farming.x"], final[i,"diff_farming.y"]), na.rm = TRUE)
  final[i, "diff_savanna_combined"] = mean(c(final[i,"diff_savanna.x"], final[i,"diff_savanna.y"]), na.rm = TRUE)
  final[i, "diff_wetland_combined"] = mean(c(final[i,"diff_wetland.x"], final[i,"diff_wetland.y"]), na.rm = TRUE)
  final[i, "diff_grassland_combined"] = mean(c(final[i,"diff_grassland.x"], final[i,"diff_grassland.y"]), na.rm = TRUE)
  final[i, "diff_urban_combined"] = mean(c(final[i,"diff_urban_infrastructure.x"], final[i,"diff_urban_infrastructure.y"]), na.rm = TRUE)
  final[i, "diff_mining_combined"] = mean(c(final[i,"diff_mining.x"], final[i,"diff_mining.y"]), na.rm = TRUE)
  final[i, "diff_mangrove_combined"] = mean(c(final[i,"diff_mangrove.x"], final[i,"diff_mangrove.y"]), na.rm = TRUE)
  #final[i, "diff_not_observed_combined"] = mean(c(final[i,"diff_not_observed.x"], final[i,"diff_not_observed.y"]), na.rm = TRUE)
}

drop <- c("mean_forest.x", "mean_savanna.x", "mean_wetland.x", "mean_grassland.x", "mean_urban_infrastructure.x", 
           "mean_mining.x", "mean_mangrove.x", "diff_forest.x", "diff_farming", "diff_savanna.x", "diff_wetland.x", "diff_grassland.x", "diff_urban_infrastructure.x", "diff_mining.x", "diff_mangrove.x", "diff_not_observed", "mean_forest.y", "mean_savanna.y", "mean_wetland.y", "mean_grassland.y", "mean_urban_infrastructure.y", "mean_mining.y", "mean_mangrove.y", 
           "diff_forest.y", "diff_savanna.y", "diff_wetland.y", "diff_grassland.y", "diff_urban_infrastructure.y", "diff_mining.y", "diff_mangrove.y")
final <- final[,!(names(final) %in% drop)]

#export final
write.csv(final, "/Users/sagemcginley-smith/Desktop/mordecai_lab/sdm_project/climate_landuse_combined_Jan2023.csv")