library(ranger)
library(pdp)
library(spatialsample)
library(sf)

analysis_data <- read.csv("/Users/sagemcginley-smith/Desktop/mordecai_lab/sdm_project/initial_training_data.csv")

#--------------------------------------------#
# get  fold  id  by  block  clustering       #
#--------------------------------------------#

#convert  analysis_data  to  a  spatial  object
data0_sf  <-  st_as_sf(x  =  analysis_data,
                       coords  =  c("longitude", "latitude"),
                       crs  =  "+proj=longlat +datum=WGS84 +ellps=WGS84")

#identify  groups  of  3  clusters  using  the  spatialsample  package
set.seed(99)  #set  seed  to  get  same  split  each  time
clusters  <-  spatial_block_cv(data0_sf, 
                               method = "random", n = 30, #method for how blocks are oriented in space & number of blocks
                               relevant_only = TRUE,  v = 3)  #k-means  clustering  to  identify  cross-validation  folds  (3  is  too  few  to  be  robust  but  using  here  to  save  time)

#for  loop  to  create  a  dataframe  that  assigns  a  fold  number  to  each  data  point
splits_df  <-  c()
for(i  in  1:3){
  new_df  <-  assessment(clusters$splits[[i]])  #extract  points  in  fold  number  i
  new_df$fold  <-  i
  new_df  <-  new_df[  c("row_identifier", "fold")]
  splits_df  <-  rbind(splits_df, new_df)  #bind  all  points  x  fold  id  together
}

splits_df  <-  st_drop_geometry(splits_df)  #drop  geometry

#final  data  -  merge  cluster  id  to  final  dataset  for  analysis
analysis_data  <-  merge(analysis_data, splits_df, by  =  "row_identifier")

#sanity  check:  check  how  many  data  points  are  in  each  fold (make sure folds have adequate data in them)
table(analysis_data$fold)


#------------------------------------#
#tune, train, model                  #
#------------------------------------#

#first  reduce  data  down  to  covariates  of  interest  (or  you  could  specify  it  in  the  formula  below)

analysis_data_v2  <-  analysis_data[  c("focal", "fold", "bio5", "bio13", "bio14", "gsl", "mean_forest_combined", "diff_forest_combined", 
                                        "mean_urban_combined", "diff_urban_combined", "mean_mining_combined", "diff_mining_combined",
                                        "mean_wetland_combined", "diff_wetland_combined")]

#for many ML algorithms  you should make sure your response variables are not grouped in the data-frame (i.e.,  all 1s and 0s next to each other)
analysis_data_v2 <- analysis_data_v2[sample(1:nrow(analysis_data_v2)), ]

#create  empty  dataframe  to  for  loop  to  store  results    one  row  for  each  fold
rf_performance  <-  data.frame(model  =  rep("RF", 3),
                               fold_id  =  1:3,
                               auc  =  rep(NA, 3),
                               focal  =  rep(NA, 3),    #number  of  presence  points  in  the  fold
                               background  =  rep(NA, 3))  #number  of  bkg  points  in  the  fold

#create  empty  dataframe  to  store  parameters  used  to  train  each  model
hypergrid_final  <-  data.frame(mtry  =  rep(NA,3),    #the  number  of  variables  to  randomly  sample  as  candidates  at  each  split
                                node_size    =  rep(NA, 3),    #minimum  number  of  samples  within  the  terminal  nodes
                                sampe_size  =  rep(NA, 3))    #the  number  of  samples  to  train  on



for(i  in  1:3){  #  run  one  iteration  per  fold
  
  train  <-  analysis_data_v2[analysis_data_v2$fold !=  i, ];  train  <-  train[-2]
  test  <-  analysis_data_v2[analysis_data_v2$fold ==  i, ];  test  <-  test[-2]
  
  #remove  any  rows  with  NAs  bc  RF  can't  handle  missing  data
  train_complete  <-  train[complete.cases(train), ]
  test_complete  <-  test[complete.cases(test), ]
  
  
  #-----------------------------------------------#
  #define  the  grid  to  search  over            #
  #-----------------------------------------------#
  #  the  function  below  creates  a  grid  with  all  combinations  of  parameters
  
  hyper_grid  <-  expand.grid(
    mtry =  seq(1, 3, by  =  1),    #the  number  of  variables  to  randomly  sample  as  candidates  at  each  split
    node_size =  seq(1,4, by  =  1),    #shallow trees
    sampe_size  =  c(.6, .70, .80),    #the  number  of  samples  to  train  on
    OOB_RMSE =  0
  )
  
  #tune  model
  for(j  in  1:nrow(hyper_grid)){
    
    #  train  model
    model  <-  ranger(
      formula  =  focal  ~  .,    
      data  =  train_complete,    
      num.trees  =  2000,  
      mtry  =  hyper_grid$mtry[j],
      min.node.size  =  hyper_grid$node_size[j],  
      sample.fraction  =  hyper_grid$sampe_size[j], 
      probability  =  TRUE, 
      replace = TRUE,
      splitrule = "hellinger",
      seed  =  123
    )
    
    #  add  OOB  error  to  grid
    hyper_grid$OOB_RMSE[j]  <-  sqrt(model$prediction.error)
  }
  
  #arrange  the  hypergrid  so  the  lowest  out-of-bag  error  (best  performing  set  of  parameters)  is  in  the  first  row
  hyper_grid2  <-  hyper_grid  %>%  
    dplyr::arrange(OOB_RMSE)
  
  #train  model
  train_model  <-  ranger(
    formula  =  focal  ~  .,    
    data  =  train_complete,   
    #use  the  first  row  of  the  grid  as  model  parameters
    num.trees  =  2000,  
    mtry  =  hyper_grid2$mtry[1], 
    min.node.size  =  hyper_grid2$node_size[1], 
    sample.fraction  =  hyper_grid2$sampe_size[1],
    probability  =  TRUE, 
    replace = TRUE,
    splitrule = "hellinger",
    seed  =  123)
  
  #save  model  performance  results
  pred0  <-  predict(train_model, data=test_complete);  pred  <-  pred0$predictions[,1]
  auc  <-  pROC::roc(response=test_complete[,"focal"], predictor=pred, levels=c(0, 1), auc  =  TRUE)
  rf_performance[i, "auc"]  <-  auc$auc
  rf_performance[i, "focal"]  <-  nrow(subset(test, focal  ==  1))
  rf_performance[i, "background"]  <-  nrow(subset(test, focal  ==  0))
  
  #save hypergrid results to use for final model
  hypergrid_final[i, "mtry"]  <-  hyper_grid2$mtry[1]
  hypergrid_final[i, "node_size"]  <-  hyper_grid2$node_size[1]
  hypergrid_final[i, "sampe_size"]  <-  hyper_grid2$sampe_size[1]
  
}

#mean auc = 0.8391129
mean(rf_performance$auc)

final_model  <-  ranger(
  formula  =  focal  ~  .,    
  data  =  analysis_data_v2[complete.cases(analysis_data_v2), -2],    #complete case dataset without fold column
  #parameters used here are the averages from hypergrid_final
  num.trees  =  2000 ,
  mtry  =  2,  
  min.node.size  =  1,  
  sample.fraction  =  0.6,
  probability  =  TRUE,  
  replace = TRUE,
  splitrule = "hellinger",
  importance  =  'permutation',    #specify  this  to  get  variable  importance  in  the  next  step
  seed  =  123)

#check in-sample auc
pred0  <-  predict(final_model, data=analysis_data_v2[complete.cases(analysis_data_v2), -2]);  pred  <-  pred0$predictions[,1]
auc  <-  pROC::roc(response=analysis_data_v2[complete.cases(analysis_data_v2), -2][,"focal"], predictor=pred, levels=c(0, 1), auc  =  TRUE)
# 0.9787
auc$auc


#------------------------------------------------------------#
# variable  importance                                       #
#------------------------------------------------------------#

#extract  model  results  to  get  permutation  importance
permutation_importance  <-  data.frame(variable  =  rownames(as.data.frame(final_model$variable.importance)),  
                                       importance  =  as.vector(final_model$variable.importance))

#plot  importance
variable_importance <- ggplot(permutation_importance, aes(x  =  variable, y  =  importance))  +
  geom_bar(stat="identity")  +
  ggtitle("permutation  importance")  +
  ylab("importance (change in model error)") + 
  coord_flip()  +
  theme_classic()

ggsave("variable_importance.png", variable_importance)
#------------------------------------------------------------#
# pdps                                                       #
#------------------------------------------------------------#

#try plotting a PDP for just one variable
pdp::partial(final_model, pred.var  =  "bio5", prob  =  TRUE, plot = TRUE, train  =  analysis_data[complete.cases(analysis_data), ])
#train = data without NAs & without "fold" column

###now run a for loop to get plotting data for all variables in the model (or in the 'var_names' list
#list of covariate names to generate pdps for and loop through
var_names  <-  names(analysis_data[complete.cases(analysis_data),  -c(13)]) #analysis dataset exlucing 'presence' and 'fold' column

#dataframe  to  make  partial  dependence  plots
pd_df  =  data.frame(matrix(vector(), 0, 3, dimnames=list(c(), c('variable', 'value', 'yhat'))),  
                     row.names  =  NULL, stringsAsFactors=F)

#loop  through  each  variable
for  (j  in  1:length(var_names))  { 
  
  output  <-  as.data.frame(pdp::partial(final_model, pred.var  =  var_names[j], prob  =  TRUE, train  = analysis_data[complete.cases(analysis_data), ]))
  
  loop_df  <-  data.frame(variable = rep(var_names[j], length(output[[1]])),
                          value  =  output[[1]],
                          yhat  =  output[[2]])
  
  pd_df  <-  rbind(pd_df, loop_df)  
}


#plot  pdps  for  each  variable
pdps <- ggplot(pd_df, aes(x  =  value, y=  yhat))  +
  geom_smooth()  +
  ylab("probability")  +
  facet_wrap(~variable, scales  =  "free")  +
  theme_bw(base_size = 14)

ggsave("pdp_plots.png", pdps)

#------------------------------------------------------------#
#prediction  map                                             #                                              
#------------------------------------------------------------#

#path for rasters of each covariate 
env_data <- list.files(path="/Users/sagemcginley-smith/Desktop/mordecai_lab/sdm_project/tif_files", pattern="tif", all.files=FALSE, full.names=TRUE,recursive=TRUE)
e <- raster::stack(env_data)

prediction_df <- as.data.frame(rasterToPoints(e)) ##this gets raster value for every grid cell of MDD

# make sure column headers match 
# adjust climate variables 

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
outfile <- writeRaster(rf_sdm_raster, filename='final_figures/rf_sdm_example_predictions.tif', format="GTiff",options=c("INTERLEAVE=BAND","COMPRESS=LZW"), overwrite=TRUE)

# example plotting
library(raster)
bio13 <- raster("/Users/sagemcginley-smith/Desktop/mordecai_lab/sdm_project/tif_files/chelsa_bio13.tif")
plot(bio13)
