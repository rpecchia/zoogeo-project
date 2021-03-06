######

#Common Myna ENM Project
#Rob Pecchia
#Zoogeography Spring 2016

#####

library(dismo)
library(dplyr)
library(maptools)
library(spThin)
library(ggplot2)
library(rgdal)
library(ENMeval)
library(scales)
library(rgeos)
library(rgdal)
data(wrld_simpl)

setwd("/Users/rpecchia/Desktop/Zoogeo Spring 2016/zoogeo-project")

####

# Download Occurrences

####

#myna_from_gbif <- gbif("Acridotheres", "tristis*", geo = TRUE)
# adding * to species will download all subspecies
# if geo = TRUE, ensures all records have latitude AND longitude
dim(myna_from_gbif)
myna_no_absences<-myna_from_gbif[!grepl("EBCC Atlas of European Breeding Birds", myna_from_gbif$datasetName),] #remove entries from EBCC
unique(myna_no_absences$country) #check to make sure absence records removed
myna_only_human_obs<-myna_no_absences[grepl("HUMAN_OBSERVATION", myna_no_absences$basisOfRecord),] #remove entries not observed by human
unique(myna_only_human_obs$basisOfRecord)
myna_points <- select(myna_only_human_obs, species, lon, lat, country) #select only necessary columns
head(myna_points)
myna_points <- myna_points[complete.cases(myna_points),] #ensure no entries are missing lat/lon/country

write.csv(myna_points, file = "myna_from_gbif.csv") #write file of species name and occurrence data

plot(wrld_simpl, axes=TRUE, col="light yellow", main = "Occurrences for Common Myna \n(Acridotheres tristis) from GBIF")
points(myna_points$lon, myna_points$lat ,col = "blue", cex = .35)

myna_unique <- unique(myna_points) #returns only unique combinations of myna points

plot(wrld_simpl, axes=TRUE, col="light yellow", main = "Occurrences for Common Myna \n(Acridotheres tristis) from GBIF")
points(myna_unique$lon, myna_unique$lat ,col = "blue", cex = .35)

####

# filtering out sightings

####
# filter(myna_unique, lat>(80)) #find northern midwest point
# points(22.01667,88.01667) #confirm this is northernmost point
# which(myna_unique$lon == 22.01667, myna_unique$lat== 88.01667) #find it in the data.frame
# myna_unique<- myna_unique[-30623,] #remove that row!
dim(myna_unique)

unique(myna_unique$country)
myna_unique <- subset(myna_unique, country != "Mexico")
myna_unique <- subset(myna_unique, country != "Austria")
myna_unique <- subset(myna_unique, country != "Brunei")
myna_unique <- subset(myna_unique, country != "Namibia")
myna_unique <- subset(myna_unique, country != "Papua New Guinea")
myna_unique <- subset(myna_unique, country != "France")
myna_unique <- subset(myna_unique, country != "Wallis and Futuna")
myna_unique <- subset(myna_unique, country != "Hong Kong")

plot(wrld_simpl, axes=TRUE, col="light yellow", main = "Occurrences for Common Myna \n(Acridotheres tristis) from GBIF")
points(myna_unique$lon, myna_unique$lat ,col = "blue", cex = .35)

#####

# Spatial Thinning

#####

crs <- CRS('+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs') # set coordinate system

myna_thin <-spThin( #thinning function
  myna_unique, 
  x.col = "lon",
  y.col = "lat",
  dist = 5000,
  method= "gurobi", #can change to "gurobi" to make it even faster, but have to install it first
  great.circle.distance=TRUE)
summary(myna_thin)

# Saving the thinned file####
print(tempdir())
write.SpThin(
  myna_thin,
  coords=FALSE,
  dir=tempdir()
)

#read in .csv of all thinned points
thin_myna2<-read.csv("thin_0001.csv", head=T)
head(thin_myna2)
thin_myna2<-thin_myna2[,1:3]
head(thin_myna2)
dim(thin_myna2)

####

# Download environmental data

####

#worldclim <- getData('worldclim', var='bio', res=2.5)
plot(worldclim[[1]], main = "Annual Mean Temp \n and Common Myna Occurrences")
points(thin_myna2$lon, thin_myna2$lat ,col = "blue", cex = .25)
points(points(myna_unique$lon, myna_unique$lat ,col = "blue", cex = .25))

plot(worldclim[[19]], main = "Precip in Coldest Quarter \n and Common Myna Occurrences")
points(points(myna_unique$lon, myna_unique$lat ,col = "blue", cex = .25))

#Pop density from SEDAC @ Columbia
population<-raster(paste(getwd(), "/Pop_density_2000/pop2.tif", sep = ""))
worldclim_and_pop <- stack(worldclim, population)

####

#Making the BioClim Model with full occurrence set

####

# myna_bioclim<-bioclim(worldclim,thin_myna_coords) #this runs and saves the BIOCLIM model as an object
# myna_bioclim_predictions <- predict(myna_bioclim, worldclim, progress='text')
# plot(myna_bioclim_predictions)
# 
# myna_bioclim_predictions_as_points <- rasterToPoints(myna_bioclim_predictions) #make predictions raster a set of points for ggplot
# df_myna_bioclim_predictions <- data.frame(myna_bioclim_predictions_as_points) #convert to data.frame
# head(df_myna_bioclim_predictions)
# colnames(df_myna_bioclim_predictions) <- c('lon', 'lat', 'Suitability') #Make appropriate column headings
# max(df_myna_bioclim_predictions$Suitability)

#####

# MaxEnt Model

####

# Jamie's mcp function
mcp_myna <- mcp(thin_myna_coords)
plot(wrld_simpl)
points(thin_myna_coords, col = "cyan4", cex = .5)
plot(mcp_myna, add = T)

# getting background points from mcp
env_mask <- mask(worldclim_and_pop, mcp_myna) #mask takes all values that are not null, and returns
env_crop <- crop(env_mask, mcp_myna)
plot(env_crop[[1]])
backg_mcp<-randomPoints(env_crop[[1]],n=10000)

plot(wrld_simpl)
points(backg, col = "darkorchid3", cex = .05)

####

# Background points from crop circles

####

#convert list of occurrences to a spatial points data.frame
myna_occurrences_spdf <- SpatialPointsDataFrame(coords = thin_myna_coords, data = thin_myna_coords,
                                                proj4string = CRS("+proj=longlat +datum=WGS84 +ellps=WGS84 +towgs84=0,0,0"))

plot(myna_occurrences_spdf)
# backg_buffered_extent <- gBuffer(myna_occurrences_spdf, width = 1) #with = degrees of the buffer
# plot(backg_buffered_extent)

# Crop and mask environmental variables by the 'crop circle' extent
# env_msk is a stack of the environmental data rasters
# env_msk_bg <- mask(worldclim_and_pop, backg_buffered_extent)
# plot(env_msk_bg[[1]])
# set.seed(1) #setting seed for random variable selection
# backg.env <- randomPoints(env_msk_bg[[1]], n=10000) #May have to try different values of agrument "tryf = 50" to get sufficient background points OR increase degrees for buffer
# plot(wrld_simpl)
# points(backg.env, col = "red", cex = .05)

# # k-fold partition background points
# #now k-fold partition background points
# colnames(backg.env) = c('lon' , 'lat')
# group <- kfold(backg, 4)
# backg_train <- backg[group != 1, ]
# backg_test <- backg[group == 1, ]

####

# ENMeval

####
## ENMEVAL TIPS####
# always keep a CSV of the same background!
# AUC full is ACU of all localities
# Mean. AUC over all iterations, then variation of AUC
# mean ormission rate at 10% threshold
# number of parameters used (is from the lambda file). #when selecting AIC, go with Delta AIC = 0
# look @results
# subset to get rid of rows with AUC, take the one with lowest delta.AICc, then plug in optimal parameters
# always keep a CSV of the same background!
# AUC full is ACU of all localities
# Mean. AUC over all iterations, then variation of AUC
# mean ormission rate at 10% threshold
# number of parameters used (is from the lambda file). #when selecting AIC, go with Delta AIC = 0
# enmeval_results <- ENMevaluate(thin_myna_coors, env = worldclim_and_pop, bg.coords = backg_five_degree ,method="block", overlap=TRUE, bin.output=TRUE, clamp=TRUE)
# enmeval_results_only <- enmeval_results@results
# save(enmeval_results, file="enmeval_results_worldclim.rdata")

# look at ENMeval for WorldClim
# plot(enmeval_results@predictions[[which (enmeval_results_worldclim@results$delta.AICc == 0) ]])
# points(enmeval_results@occ.pts, pch=21, bg=enmeval_results@occ.grp)
# head(enmeval_results@results)
# enmeval_results@results #all the results
# Q_enmeval<-enmeval_results@results#arrange by AICc value
# QQ_enmeval<-as.data.frame(Q_enmeval)
# head(QQ_enmeval)
# QQ_enmeval<-QQ_enmeval[,c(1,2,3,14)]
# head(QQ_enmeval)
# arrange(QQ_enmeval,AICc,settings,features,rm) #this will sort ENMeval results so that we can see exact settings for model with lowest AICc
## Shows that model with LQ ranging from .5-4.0 all had the lowest AICc
# enmeval_resultsm@overlap

# # ENMeval Figures
# par(mfrow=c(2,2))
# eval.plot(enmeval_results@results, legend.position="topright")
# eval.plot(enmeval_results@results, "Mean.AUC")
# eval.plot(enmeval_results@results, "Mean.AUC.DIFF", variance="Var.AUC.DIFF")
# eval.plot(enmeval_results@results, "Mean.ORmin")
# enmeval_results@results
# specify how data should be partitioned w/ method="jackknife", "randomkfold", "user", "block", "checkerboard1", "checkerboard2".
# n.bg is The number of random background localities to draw from the study extent
# when overlap = TRUE, provides pairwise metric of niche overlap 
# bin.output appends evaluations metrics for each evaluation bin to results table

#subset to get rid of rows with AUC, take the one with lowest delta.AICc, then plug in optimal parameters

# # Which settings gave delta.AICc < 2?
# aicmods <- which(res@results$delta.AICc < 2)
# res@results[aicmods,]
# 
# # Visualize how data were partitioned
# # Background points:
# plot(env[[2]], xlim=c(-67.5,-65.5))
# points(res@bg.pts, col= res@bg.grp, cex=.75)
# 
# # Occurrence localities:
# plot(res@predictions[[which(res@results$delta.AICc == 0)]], xlim=c(-67.5,-65.5))
# points(res@occ.pts, pch=16, col= res@occ.grp, cex=.75)
# 
# # View predictions in geographic space for these models
# plot(res@predictions[[aicmods]])

#####

# MaxEnt with DEFAULT settings, NO background

#####
#can get points from bounding box
backg_bb <- randomPoints(worldclim_pop_landcover, n=10000, ext = (extent(-179.988, 179.97, -43,51.6714)))
mx_myna_bb <- maxent(worldclim_and_pop, train, a = backg_bb, args=c('betamultiplier=3','responsecurves=TRUE','writebackgroundpredictions=TRUE'))
mx_myna_bb@results

####

# MaxEnt with DEFAULT settings, MCH background

####
plot(train)
mx_myna_mcp_defaults <- maxent(worldclim_and_pop, train, a = backg_mcp, args=c('responsecurves=TRUE','writebackgroundpredictions=TRUE'))
mx_myna_mcp_defaults

####

# MaxEnt with RM = 3, MCH background, 10-fold

####

mx_myna_mcp <- maxent(worldclim_and_pop, thin_myna_coords, a = backg_mcp, args=c('doclamp=TRUE','responsecurves=TRUE','writebackgroundpredictions=TRUE','replicatetype=crossvalidate', 'replicates=10'))
mx_myna_mcp
mx_myna_mcp@presence #raster of suitability values for presences
mx_myna_mcp@absence #raster of suitability values for absences

#all occurrences for final model
mx_myna_mcp_all_occs <- maxent(worldclim_and_pop, thin_myna_coords, a = backg_mcp, args=c('betamultiplier=3','responsecurves=TRUE','writebackgroundpredictions=TRUE'))
mx_myna_mcp_all_occs@lambdas
mx_myna_mcp_all_occs@results
plot(mx_myna_mcp_all_occs)

px_myna_mcp_all_occs <- predict(worldclim_and_pop, mx_myna_mcp_all_occs) #make predictions of habitat suitability can include argument ext=ext
plot(px_myna_mcp_all_occs, main= 'Maxent, raw values')
writeRaster(px_myna_mcp_all_occs, filename="myna_all_occs_MCH_for_qgis.tif", format="GTiff", overwrite=TRUE) #exporting a GEOtiff

# Threshold w/ minimum 10% training presence
# training_suitability_myna <- extract(px_myna_all_occs, thin_myna_coords) #all predicted values, all occs
# ten_thresh_myna <- quantile(training_suitability_myna, 0.1, na.rm = TRUE)
# ten_thresh_myna

# #creating binary map
# threshold_map <- px_myna_all_occs > ten_thresh_myna
# plot(px_myna_all_occs > ten_thresh_myna)
# plot(threshold_map)
# writeRaster(threshold_map, filename="myna_threshold_map.tif", format="GTiff", overwrite=TRUE) #exporting a GEOtiff

#### 

# Maxent w/ Background from CROP CIRCLES worldclim and population

####

# write the SPDF of myna points for QGIS
writeOGR(myna_occurrences_spdf, dsn = "data/",layer = "myna_csv_spdf_as_shp", driver = "ESRI Shapefile")

#now read in the file w/ buffers
buffered_region_five <- readGDAL("data/buffer_layer_cropped_five.tif")

#convert buffered region to raster
buffered_region_raster_five <- raster(buffered_region_five) #convert africa map to raster
backg_five_degree <- randomPoints(buffered_region_raster_five, n=20000)

plot(wrld_simpl)
points(backg_five_degree, col = "red", cex = 0.2)

mx_myna_crop_k_fold_qgis_five <- maxent(worldclim_and_pop, thin_myna_coords, a = backg_five_degree, args=c('doclamp=TRUE','responsecurves=TRUE', 'replicatetype=crossvalidate', 'replicates=10','writebackgroundpredictions=TRUE','outputgrids=TRUE'))
mx_myna_crop_k_fold_qgis_five
mx_myna_crop_k_fold_qgis_five@results

mx_myna_all_occs_five_degree <- maxent(worldclim_and_pop, thin_myna_coords, a = backg_five_degree, args=c('doclamp=TRUE','responsecurves=TRUE','writebackgroundpredictions=TRUE','outputgrids=TRUE'))
plot(mx_myna_all_occs_five_degree)
response(mx_myna_all_occs_five_degree)

#Make predictions for whole world
px_myna_all_occs_five_degree <- predict(worldclim_and_pop, mx_myna_all_occs_five_degree) #make predictions of habitat suitability can include argument ext=ext
plot(px_myna_all_occs_five_degree, main= 'Maxent, raw values')
writeRaster(px_myna_all_occs_five_degree, filename="myna_five_degree_all_occs_for_qgis.tif", format="GTiff", overwrite=TRUE) #exporting a GEOtiff

####

# MaxEnt with crop circle background NO POPULATION

####

# myna model with no population covariate
plot(backg_five_degree)
mx_myna_no_pop_k_fold <- maxent(worldclim, thin_myna_coords, a = backg_five_degree, args=c('doclamp=TRUE','responsecurves=TRUE', 'replicatetype=crossvalidate', 'replicates=10','writebackgroundpredictions=TRUE','outputgrids=TRUE'))
mx_myna_no_pop_k_fold@results

#full occurrences
mx_myna_no_pop <- maxent(worldclim, thin_myna_coords, a = backg_five_degree, args=c('doclamp=TRUE','responsecurves=TRUE','writebackgroundpredictions=TRUE','outputgrids=TRUE'))
mx_myna_no_pop

px_myna_myna_no_pop <- predict(worldclim, mx_myna_no_pop) #make predictions of habitat suitability can include argument ext=ext
plot(px_myna_myna_no_pop, main= 'Maxent, raw values')
writeRaster(px_myna_myna_no_pop, filename="myna_no_pop_for_qgis.tif", format="GTiff", overwrite=TRUE) #exporting a GEOtiff


####

# Blocking in ENMeval

####
thin_myna_coords2<-thin_myna_coords
backg_five_degree2<-as.data.frame(backg_five_degree)
names(thin_myna_coords2) <- c("xocc","yocc")
names(backg_five_degree2)<-c("xbg", "ybg")
myna_blocks <- get.block(thin_myna_coords2, backg_five_degree2) 
plot(wrld_simpl)
points(thin_myna_coords2, pch=23, bg=myna_blocks$occ.grp)
plot(wrld_simpl)
points(backg_five_degree2, pch=21, bg=myna_blocks$bg.grp)

#### BLOCK 1 #####
coords_for_blocks <- thin_myna_coords2
blocks_and_occs <- cbind(coords_for_blocks, myna_blocks$occ.grp)
head(blocks_and_occs)
train<-blocks_and_occs[myna_blocks$occ.grp>1,] #training has 75% of points
test<-blocks_and_occs[myna_blocks$occ.grp==1,] #testing has 25% of points
train<-train[,1:2]
test<-test[,1:2]
names(train) <- c("lon","lat")
names(test) <- c("lon","lat")

coords_for_backg <- cbind(backg_five_degree2, myna_blocks$bg.grp)
train_backg<-coords_for_backg[myna_blocks$bg.grp>1,] 
test_backg<-coords_for_backg[myna_blocks$bg.grp==1,]
train_backg<-train_backg[,1:2]
test_backg<-test_backg[,1:2]
names(train_backg) <- c("lon","lat")
names(test_backg) <- c("lon","lat")

mx_myna_block1 <- maxent(worldclim_and_pop, train, a = train_backg, args=c('doclamp=TRUE','responsecurves=TRUE','writebackgroundpredictions=TRUE','outputgrids=TRUE'))
mx_myna_block1

block1_eval <- evaluate(test, test_backg, mx_myna_block1, worldclim_and_pop) #evalute test points, pseudo-absences (random background points), the model and predictors
block1_eval

#### BLOCK 2 #####
train2<-blocks_and_occs[myna_blocks$occ.grp > 2 | myna_blocks$occ.grp < 2,] #training has 75% of points
test2<-blocks_and_occs[myna_blocks$occ.grp==2,] #testing has 25% of points
train2<-train2[,1:2]
test2<-test2[,1:2]
names(train2) <- c("lon","lat")
names(test2) <- c("lon","lat")

coords_for_backg <- cbind(backg_five_degree2, myna_blocks$bg.grp)
train_backg2<-coords_for_backg[myna_blocks$bg.grp>2 | myna_blocks$bg.grp < 2 ,] 
test_backg2<-coords_for_backg[myna_blocks$bg.grp==2,]
train_backg2<-train_backg2[,1:2]
test_backg2<-test_backg2[,1:2]
names(train_backg2) <- c("lon","lat")
names(test_backg2) <- c("lon","lat")

mx_myna_block2 <- maxent(worldclim_and_pop, train2, a = train_backg2, args=c('doclamp=TRUE','responsecurves=TRUE','writebackgroundpredictions=TRUE','outputgrids=TRUE'))
mx_myna_block2

block2_eval <- evaluate(test2, test_backg2, mx_myna_block2, worldclim_and_pop) #evalute test points, pseudo-absences (random background points), the model and predictors
block2_eval

#### BLOCK 3 #####
train3<-blocks_and_occs[myna_blocks$occ.grp > 3 | myna_blocks$occ.grp < 3,] #training has 75% of points
test3<-blocks_and_occs[myna_blocks$occ.grp==3,] #testing has 25% of points
head(train3)
train3<-train3[,1:2]
test3<-test3[,1:2]
names(train3) <- c("lon","lat")
names(test3) <- c("lon","lat")

coords_for_backg <- cbind(backg_five_degree2, myna_blocks$bg.grp)
train_backg3<-coords_for_backg[myna_blocks$bg.grp>3 | myna_blocks$bg.grp < 3 ,] 
test_backg3<-coords_for_backg[myna_blocks$bg.grp==3,]
train_backg3<-train_backg3[,1:2]
test_backg3<-test_backg3[,1:2]
names(train_backg3) <- c("lon","lat")
names(test_backg3) <- c("lon","lat")

mx_myna_block3 <- maxent(worldclim_and_pop, train3, a = train_backg3, args=c('doclamp=TRUE','responsecurves=TRUE','writebackgroundpredictions=TRUE','outputgrids=TRUE'))
mx_myna_block3

block3_eval <- evaluate(test3, test_backg3, mx_myna_block3, worldclim_and_pop) #evalute test points, pseudo-absences (random background points), the model and predictors
block3_eval


####### BLOCK 4 #######

train4<-blocks_and_occs[myna_blocks$occ.grp < 4,] #training has 75% of points
test4<-blocks_and_occs[myna_blocks$occ.grp==4,] #testing has 25% of points
head(train4)
train4<-train4[,1:2]
test4<-test4[,1:2]
names(train4) <- c("lon","lat")
names(test4) <- c("lon","lat")

coords_for_backg <- cbind(backg_five_degree2, myna_blocks$bg.grp)
train_backg4<-coords_for_backg[myna_blocks$bg.grp < 4 ,] 
test_backg4<-coords_for_backg[myna_blocks$bg.grp==4,]
train_backg4<-train_backg4[,1:2]
test_backg4<-test_backg4[,1:2]
names(train_backg4) <- c("lon","lat")
names(test_backg4) <- c("lon","lat")

mx_myna_block4 <- maxent(worldclim_and_pop, train4, a = train_backg4, args=c('doclamp=TRUE','responsecurves=TRUE','writebackgroundpredictions=TRUE','outputgrids=TRUE'))
mx_myna_block4

block4_eval <- evaluate(test4, test_backg4, mx_myna_block4, worldclim_and_pop) #evalute test points, pseudo-absences (random background points), the model and predictors
block4_eval

#####

# ENMeval Blocking function

#####

# get.block <- function(occ, bg.coords){
#   # SPLIT OCC POINTS INTO FOUR SPATIAL GROUPS
#   noccs <- nrow(occ)
#   n1 <- ceiling(nrow(occ)/2)
#   n2 <- floor(nrow(occ)/2)
#   n3 <- ceiling(n1/2)
#   n4 <- ceiling(n2/2)
#   grpA <- occ[order(occ[, 2]),][1:n1,]
#   grpB <- occ[rev(order(occ[, 2])),][1:n2,]
#   grp1 <- grpA[order(grpA[, 1]),][1:(n3),]
#   grp2 <- grpA[!rownames(grpA)%in%rownames(grp1),]
#   grp3 <- grpB[order(grpB[, 1]),][1:(n4),]
#   grp4 <- grpB[!rownames(grpB)%in%rownames(grp3),]
#   
#   # SPLIT BACKGROUND POINTS BASED ON SPATIAL GROUPS
#   bvert <- mean(max(grp1[, 1]), min(grp2[, 1]))
#   tvert <- mean(max(grp3[, 1]), min(grp4[, 1]))
#   horz <- mean(max(grpA[, 2]), min(grpB[, 2]))
#   bggrp1 <- bg.coords[bg.coords[, 2] <= horz & bg.coords[, 1]<bvert,]
#   bggrp2 <- bg.coords[bg.coords[, 2] < horz & bg.coords[, 1]>=bvert,]
#   bggrp3 <- bg.coords[bg.coords[, 2] > horz & bg.coords[, 1]<=tvert,]
#   bggrp4 <- bg.coords[bg.coords[, 2] >= horz & bg.coords[, 1]>tvert,]
#   
#   r <- data.frame()
#   if (nrow(grp1) > 0) grp1$grp <- 1; r <- rbind(r, grp1)
#   if (nrow(grp2) > 0) grp2$grp <- 2; r <- rbind(r, grp2)
#   if (nrow(grp3) > 0) grp3$grp <- 3; r <- rbind(r, grp3)
#   if (nrow(grp4) > 0) grp4$grp <- 4; r <- rbind(r, grp4)
#   occ.grp <- r[order(as.numeric(rownames(r))),]$grp
#   
#   bgr <- data.frame()
#   if (nrow(bggrp1) > 0) bggrp1$grp <- 1; bgr <- rbind(bgr, bggrp1)
#   if (nrow(bggrp2) > 0) bggrp2$grp <- 2; bgr <- rbind(bgr, bggrp2)
#   if (nrow(bggrp3) > 0) bggrp3$grp <- 3; bgr <- rbind(bgr, bggrp3)
#   if (nrow(bggrp4) > 0) bggrp4$grp <- 4; bgr <- rbind(bgr, bggrp4)
#   bg.grp <- bgr[order(as.numeric(rownames(bgr))),]$grp
#   
#   out <- list(occ.grp=occ.grp, bg.grp=bg.grp)
#   return(out)
# }

####

#Jamie's Minimum Convex Polygon Function

#####

# mcp <- function (xy) {
#   # handler for spatial objects -- extracts coordinates
#   if (class(xy) == "SpatialPoints" | class(xy) == "SpatialPointsDataFrame") {
#     xy <- as.data.frame(coordinates(xy))
#   }
#   # get mcp indices
#   i <- chull(xy)
#   # get rows in xy for i
#   xy.mcp <- xy[i,]
#   # copy first row to last position to close shape
#   xy.mcp <- rbind(xy.mcp[nrow(xy.mcp),], xy.mcp)
#   # return polygon of mcp
#   return(SpatialPolygons(list(Polygons(list(Polygon(as.matrix(xy.mcp))), 1))))
# }

####

# Function for calculating # of parameters in each model

####
#First, read in lambdas file
# curpath <- "/private/var/folders/ws/_8nc2k3x5fjf4w5tnzxr95wh0000gn/T/R_raster_rpecchia/maxent/1577985387"
# rf <- read.table(file.path(curpath, 'species.lambdas'), sep=',', fill=TRUE)
# # record no. of params (restrict df to rows with four values and no 0 in 2nd column)
# p <- nrow(rf[!is.na(rf[3]) & rf[2] != 0,])
# p