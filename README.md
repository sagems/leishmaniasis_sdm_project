# Leishmaniasis SDM Project 

Sage McGinley-Smith 

Mordecai Lab, Stanford University

Winter 2023 

## Table of Contents :books:

- [Retrieving Climate and Land Use Data](#one)
- [Cleaning Training Data in R](#two)
- [Variable Importance and Selection](#three)
- [Retrieving and Rasterizing All Projected Data](#four)
- [Making Projection Maps](#five)

## Retrieving Land Use and Climate Data :cloud:

To create a training dataset for my model, I used Google Earth Engine to collect climate and land use variable values for each of the known sandfly occurence points. The occurence points used for this section are found in sandfly_vectors.csv. The code below pulls climate data from the CHELSA climate databasefor the years 1982-2010 for each of the occurence points and saves it to a csv file in Google Drive. 

```gee
//this code downloads CHELSA data as decadal averages
//add shapefiles to make it easy to reduce images to Brazil
// var region = ee.FeatureCollection('users/cglidden/Amazon_Basin');

//read in image collections, conver to images (?), add bands so one giant image collection
var chelsa = ee.ImageCollection("users/cglidden/CHELSA_1981_2010")
                  .toBands()
                  .reproject("EPSG:4326", null, 1000)
                  //.clip(region)
print(chelsa) //make sure each image is now a band

//specify path to sandfly points, making sure there is an index
var pnt_data = ee.FeatureCollection('users/sagems/sandfly_vectors_renamed');

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

This code block pulls land use data for the same occurence points.

## Cleaning Training Data :broom:

## Variable Importance and Selection :trophy:

## Retrieving and Rasterizing All Projected Data :mountain:

## Making Projection Maps :airplane:
