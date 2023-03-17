# Leishmaniasis SDM Project 

Sage McGinley-Smith 

Mordecai Lab, Stanford University

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

Bio 1 - Mean Annual Air Temperature 

Bio 5 - Mean Daily Max Air Temp of the Warmest Month

Bio 6 - Mean Daily Min Air Temp of the Coldest Month

Bio 7 - Annual Air Temp Range

Bio 12 - Annual Precipitation Amount

Bio 13 - Precipitation in the Wettest Month

Bio 14 - Precipitation in the Driest Month

GSL - Growing Season Length

GSP - Total Precipitation on Growing Season Days

GST - Mean Temperature on Growing Season Days

NPP - Net Primary Productivity

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

## Variable Importance and Selection :trophy:


## Building Model

With the focal and background data retrieved and the variables selected, I used R to run a random forest model on my training data. I used a 

## Retrieving and Rasterizing All Projected Data :mountain:

## Making Projection Maps :airplane:

Using the projected land use and climate rasters created in the previous step, I used the below R code to create a projection map for the Amazon that shows the model's probabilistic distribution of the Bichromomyia flaviscutellata vector based on the provided climate and land-use variables. The code used is pasted below, and the distribution map created is also shown. 

```{r}
insert map code here
```
![Projection Map for Bichromomyia flaviscutellata Distribution in the Amazon Basin](image.jpg "Projection Map for Bichromomyia flaviscutellata Distribution in the Amazon Basin")
