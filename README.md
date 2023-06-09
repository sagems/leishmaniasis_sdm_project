# Building a Species Distribution Model for Leishmaniasis

Sage McGinley-Smith

[Mordecai Lab](https://www.mordecailab.com/), Stanford University

Mentors: Caroline Glidden and Aly Singleton

Project Funded by Stanford University Vice Provost for Undergraduate Education [Small Grant](https://undergradresearch.stanford.edu/fund-your-project/explore-student-grants/small)

Winter 2023


## Table of Contents :books:

- [Retrieving Climate and Land Use Data](#one)
- [Cleaning Training Data in R](#two)
- [Thinning for Chosen Species](#three)
- [Variable Importance and Selection](#four)
- [Retrieving and Rasterizing All Projected Data](#five)
- [Making Projection Maps](#six)

## Retrieving Land Use and Climate Data :cloud:

To create a training dataset for my model, I used Google Earth Engine to collect climate and land use variable values for each of the known sandfly occurence points. The sandfly occurence points used for this project sandfly_vectors.csv. 

For the climate data, I used a dataset from CHELSA that captured climatological variables for the entire area spanned by my occurence points. Average values were calculated for each of the below climatological variables in a 1km^2 buffer region around each occurence point. The dataset includes information from 1981-2010. 

Variables were selected based on hypothesized importance as well as availblility of future projection data. Climate variables collected preliminarily were:

- Bio 1 - Mean Annual Air Temperature 

- Bio 5 - Mean Daily Max Air Temp of the Warmest Month

- Bio 6 - Mean Daily Min Air Temp of the Coldest Month

- Bio 7 - Annual Air Temp Range

- Bio 12 - Annual Precipitation Amount

- Bio 13 - Precipitation in the Wettest Month

- Bio 14 - Precipitation in the Driest Month

- GSL - Growing Season Length

- GSP - Total Precipitation on Growing Season Days

- GST - Mean Temperature on Growing Season Days

- NPP - Net Primary Productivity

Descriptions of all climate variables available (via CHELSA): https://chelsa-climate.org/wp-admin/download-page/CHELSA_tech_specification_V2.pdf

I then used GEE to pull land use data for the same set of occurence points. I found that most occurence points were captured within a MapBiomas dataset that provided land use data for Brazil and well as one for the Amazon. In using that dataset, several occurence points were excluded. The number that was excluded was low, but adding other MapBiomas datasets to cover more of the land area and thus encompass more data points would be part of building a more comprehensive model. 

To summarize value for land use classes, I created a 1km buffer around each vector occurence point and calculated the percentage of the area that was each designated land class. Below is the link to the earth engine code used for both the land use and climate data collection. 

GEE code for climate data: https://code.earthengine.google.com/48cc74734ca09117ad42eab5d2073baa

GEE code for land use (brazil): https://code.earthengine.google.com/3f1e49f4185c5dfbe3ba2dc76ebe3c89

GEE code for land use (amazon): https://code.earthengine.google.com/f7a5b88e2bb9f04d5469c712f0cfb7ca

## Cleaning Training Data :broom:

The next step in building the model was cleaning the training data in R. Full code for this section can be found in 1cleaning_climate_landuse_data.R. 

For the climate data, I adjusted all temperature values to be in Celcius and all precipitation values to be in mm to maintain consistency. For the land use data, I pivoted both the amazon and brazil sheets from wide to long and merged them, calcualting mean and difference values across years for each occurence point. Some occurnece points had data from in the amazon set, while some had data in the Brazil set, but once merged I had land use data from most of the occurence points from the original dataset. I then combined the land use and climate data for each occurence point and created histograms of the resulting values as a way to ensure my calcualtions were relatively correct. Those histograms can be found in the histograms folder of this respository.

## Thinning for Chosen Species

From the cleaned data, I selected a single species to be used as my focal species, and designated the rest of my species to be background data. The focal species I chose was Bichromomyia flaviscutellata, chosen based on sufficiency of data for the individual species, as well as its presence as a competent vector in past literature and predicted competence as a vector based on a model built by Gowri Vadmal (gvadmal@stanford.edu) in the Mordecai Lab. The purpose of selecting a focal species and background species is to account for sampling bias, which might occur if areas that were sampled were considered to be areas where the focal species was not present. Having a focal and background species allows my model to learn associations between variables and the presence or absence of the focal species in areas that were surveyed without being skewed by data from areas where presence of the focal species is unknown. 

Code for this section can be found in 2thinning_for_species.R. The code thins the data using a probability mask and selects appropriate focal and background points. There are roughly twice the number of background points as there are focal points.

## Variable Selection :trophy:
Before running the model, the final step was to select final variables to use in the model. For the sake of conserving computational resources and time, I decided to limit the number of variables I selected to 12. This included the following climate and land use variables: 

- Bio 5 - Mean Daily Max Air Temp of the Warmest Month

- Bio 13 - Precipitation in the Wettest Month

- Bio 14 - Precipitation in the Driest Month

- GSL - Growing Season Length

- Mean and Difference of Forest Cover 

- Mean and Difference of Urban Cover 

- Mean and Difference of Wetland Cover 

- Mean and Difference of Mining Cover

The variables were thinned to this list using a correlation analysis. The code below displays a correlation plot for the variables (also shown below). If two variables had a correlation greater than 0.70, one variable was eliminated. The chosen eliminated one was selected based on frequency of correlation with other variables, as well as hypothesized importance in the model based on past literature.

```{r}
# install.packages("corrplot")
library(corrplot)
library(ggplot2)

climate_land_use <- read.csv("/Users/sagemcginley-smith/Desktop/mordecai_lab/sdm_project/background_occurence_thinned.csv")
drop <- c("bio1", "bio5", "bio6", "bio12", "bio13", "bio14", "bio7", "gsl", "mean_forest_combined", "diff_forest_combined", 
          "mean_urban_combined", "diff_urban_combined", "mean_mining_combined", "diff_mining_combined", "mean_wetland_combined", "diff_wetland_combined")
climate_land_use <- climate_land_use[,(names(climate_land_use) %in% drop)]

data <- cor(climate_land_use)

p <- corrplot.mixed(data,
               lower = "number", 
               upper = "circle",
               tl.col = "black")

climate_data <- read.csv("/Users/sagemcginley-smith/Desktop/mordecai_lab/sdm_project/background_occurence_thinned.csv")

drop <- c("latitude", "longitude", "row_identifier", "focal","bio5", "bio13", "bio14", "gsl", "mean_forest_combined", "diff_forest_combined", 
          "mean_urban_combined", "diff_urban_combined", "mean_mining_combined", "diff_mining_combined", "mean_wetland_combined", "diff_wetland_combined")
climate_data <- climate_data[,(names(climate_data) %in% drop)]
write.csv(climate_data, "/Users/sagemcginley-smith/Desktop/mordecai_lab/sdm_project/initial_training_data.csv")
```

<img src="corr_plot.png" alt="Correlation Plot for All Variables" width="700" height="700" align="center">

## Building Model

With the focal and background data retrieved and the variables selected, I used R to run a random forest model on my final training data. Training data can be found in initial_training_data.csv. I used k-means clustering with three cross-validation folds to test the robustness and accuracy of my model and found the model to have an averages Area Under Curve (auc) of 0.8391129 across the three fold tests. 

From this tuned model, I was able to predict both variable importance and create partial dependency plots for each variable. Both are pictured below. R code for the modeling part of this project can be found in 4model_building.R. 

<img src="variable_importance.png" alt="Charting Variable Importance for All Variables" width="500" height="500">

<img src="pdp_plots.png" alt="Partial Dependency Plot for All Variables" width="600" height="500">

## Retrieving and Rasterizing All Projected Data :mountain:

In order to use the model to make current projection, I collected land use and climate data for the entire Amazon Basin and fed it into my final model to build prediction maps of vector distribution in areas that haven't been sampled for Bichromomyia flaviscutellata. To collect the necessary climate data, I used the following code in Google Earth Engine to generate rasters for each of the climate variables across the designated area: 

```gee
//this code downloads CHELSA data as decadal averages
//add shapefiles to make it easy to reduce images to Brazil
var region = ee.FeatureCollection('users/cglidden/Amazon_Basin');
var pnt_data = ee.FeatureCollection('users/cglidden/1km_grid_amazon');


//read in image collections, conver to images (?), add bands so one giant image collection
var chelsa = ee.ImageCollection("users/cglidden/CHELSA_1981_2010")
                  .toBands()
                  .reproject("EPSG:4326", null, 1000)
                  .clip(region)
                  .select("bio5_b1", "bio13_b1", "bio14_b1", "gsl_b1")
//print(chelsa) //make sure each image is now a band

// run image sample as export -- this exports data for each snail point at a 1km resolution, which is the resolution of the data
Export.table.toDrive({
  collection: chelsa.reduceRegions({
    collection: pnt_data,
    reducer: ee.Reducer.mean(),
    scale: 1000,
    tileScale: 16
    }),
  description: 'chelsea_data',
  folder: 'GEEexports',
  fileFormat: 'csv',
  });
```

Direct link to GEE code for creating climate rasters: https://code.earthengine.google.com/8ddd180d2c775b296e02cea70b47e1ff
              
For the land use data, I used GEE to create a csv file containing percentage land coverage data for all 1km^2 buffer regions in the specified area. The code for this section can be found at the following GEE link: https://code.earthengine.google.com/48ed99772fe32dd48b485283c17ef9fc

From there, I cleaned the data in a similar manner to the training data process, and used the 'raster' package in R to convert the values to .tif files. The R code for this section can be found in present_land_use_tifs.R, and all .tif files for both climate and land use can be found in the tif_files folder. 

## Making Projection Maps :airplane:

Using the projected land use and climate rasters created in the previous step, I used the below R code to create a projection map for the Amazon that shows the model's probabilistic distribution of the Bichromomyia flaviscutellata vector based on the provided climate and land-use variables. The code used is pasted below, and the distribution map created is also shown. 

```{r}
#------------------------------------------------------------#
#prediction  map                                             #                                              
#------------------------------------------------------------#

#path for rasters of each covariate 
env_data <- list.files(path="/Users/sagemcginley-smith/Desktop/mordecai_lab/sdm_project/tif_files", pattern="tif", all.files=FALSE, full.names=TRUE,recursive=TRUE)
e <- raster::stack(env_data)

prediction_df <- as.data.frame(rasterToPoints(e)) ##this gets raster value for every grid cell of MDD

#reduce dataset to complete cases
prediction_df_complete <- prediction_df[complete.cases(prediction_df), ]

#predict probability of species occurrence each 1km grid cell of the area of interest
predictions <- predict(final_model,
                       data=prediction_df_complete)

prediction_df_full <- cbind(prediction_df_complete, as.data.frame(predictions$predictions)[,2])
names(prediction_df_full)[ncol(prediction_df_full)] <- "probability"

#reduce dataset to only the long(x), lat (y), and variable of interest (probability)
rf_tiff_df <- prediction_df_full[, c("x", "y", "probability")]

rf_sdm_raster <- rasterFromXYZ(rf_tiff_df)

#save raster
outfile <- writeRaster(rf_sdm_raster, filename='/Users/sagemcginley-smith/Desktop/mordecai_lab/sdm_project/current_projections.tif', format="GTiff",options=c("INTERLEAVE=BAND","COMPRESS=LZW"), overwrite=TRUE)
```
![Projection Map for Bichromomyia flaviscutellata Distribution in the Amazon Basin](image.jpg "Projection Map for Bichromomyia flaviscutellata Distribution in the Amazon Basin")
