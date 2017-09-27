#!/usr/bin/R

## This file handles the generation of the cartogram according to
## Mark Newmans http://www-personal.umich.edu/~mejn/cart/ algorithm
## and the corresponding R implementation

###################################################################
####################### Prerequisites #############################
###################################################################

## Required packages
library( devtools ) # To install the package from Github
library( ggplot2 ) # For plotting the results
library( dplyr ) # For reshaping and selecting the election results
library( rgdal ) # For importing the shape files
library( maptools ) # and their handling

## Loading the election results.
load( "data/bundeswahlleiter/current_election.RData" )

## Import the shape files
election.districts <- readOGR( dsn = "data/bundeswahlleiter/.",
                              layer = "Geometrie_Wahlkreise_19DBT_geo",
                              p4s = NULL )

## Converting the spatial object into a data.frame better suited
## for the 'ggplot2' package.
election.districts.df <- fortify( election.districts )

## Installing the Rcartogram package. Since it's not on CRAN we will
## use my Github fork. (The predict.Cartogram method of the original
## one is erroneous)
install_github( "theGreatWhiteShark/Rcartogram" )

###################################################################
#################### Density generation ###########################
###################################################################
## The package's code is a port to Newman's original C version of
## the algorithm. http://www-personal.umich.edu/~mejn/cart/doc/
## The basic ingredient we need here is a density map on a regular
## grid containing the election results per election district.
## This map we will afterwards embed in a 'sea' of the overall
## average value of quite generous size.

## Overall range of the polygons of the election districts
election.districts.range <- election.districts@bbox

## Let's make the size of the grid explicit.
number.of.grid.points.y <- 1024
number.of.grid.points.x <- round( number.of.grid.points.y/ 2 )

## Span an uniform grid of points covering this very range.
## We will use the SpatialPoints object instead of a data.frame
## here, since it is required by the sp::over function we'll
## use in the next step.
density.grid.x <-  seq( election.districts.range[ 1, 1 ],
                       election.districts.range[ 1, 2 ],
                       length.out = number.of.grid.points.x )
density.grid.y <-  seq( election.districts.range[ 2, 1 ],
                       election.districts.range[ 2, 2 ],
                       length.out = number.of.grid.points.y )
density.grid <- SpatialPoints( expand.grid(
    density.grid.x, density.grid.y ),
    proj4string = election.districts@proj4string )

## Check which point falls within which polygon/election
## district.
density.point.in.polygon <- over( density.grid, election.districts )

## Collect the results in a data.frame
density.df <- data.frame(
    x = density.grid@coords[ , 1 ], y = density.grid@coords[ , 2 ],
    election.district.number =
      as.numeric( as.character(
          density.point.in.polygon$WKR_NR ) ) )
## as.numeric( as.character( ... ) )? Well, without the
## conversion to character the numerical conversion will
## output wrong number in the right range resulting in a
## wrong distribution of the election districts. Stupid !@#$!@#

## Extract the number of votes for a certain party and type
## of vote for all election districts from the tidied results.
select.party <- "DIE LINKE"
select.type.of.vote <- "Zweitstimmen"
select.confirmation.status <- "Vorläufig"
select.counts <- select(
    filter( current.election,
           party == select.party &
           type.of.vote == select.type.of.vote &
           confirmation.status == select.confirmation.status &
           county.number != 99 ),
    election.district.number, counts )

## Assign the corresponding number of votes to the election
## district the individual points did fall into.
density.df <- left_join( density.df, select.counts,
                        by = "election.district.number" )

## Fill all NA in the number of votes with the mean value.
## This is what the authors called the 'sea'.
density.df$counts[ is.na( density.df$counts ) ] <-
  mean( density.df$counts, na.rm = TRUE )

## Visual check of the density map
ggplot( data = density.df ) +
  geom_tile( aes( x = x, y = y, alpha = counts ),
            fill = '#df0404' ) +
coord_quickmap() + theme_minimal() + xlab( "" ) + ylab( "" ) +
  scale_alpha_continuous( guide = FALSE )
## Alright, everything looks fine.

density.matrix <- matrix( as.numeric( density.df$counts ),
                         nrow = number.of.grid.points.x,
                         ncol = number.of.grid.points.y )

## These intermediate step you can visualize using e.g
image( density.grid.x, density.grid.y, density.matrix )


###################################################################
####################### calculating the cartogram #################
###################################################################
density.cartogram <- cartogram( density.matrix )

election.districts.df <- fortify( election.districts )

## Convert the IDs of the polygons to the same key used to
## identify the election districts.
election.districts.df$election.district.number <-
  as.numeric( election.districts.df$id ) + 1

## Add the counts to all points of the corresponding polygons
election.districts.df <- left_join( election.districts.df,
                                   select.counts,
                                   by ="election.district.number")

## Now we have two options of obtaining the transformed coordinates
## of the cartogram.
##
## 1. Rcartogram package
##
## Calculating the new coordinates for the vertices in the
## cartogram using the wrappers provided by the Rcartogram
## package.
cartogram.values.R <- predict( density.cartogram,
                            election.districts.df$long,
                            election.districts.df$lat )

## 2. Newman's pure C code
##
## As an alternative I provided the original C code of Newman in
## version 1.2.2 http://www-personal.umich.edu/~mejn/cart/download/
## As a prerequisite we have to create an auxiliary folder, copy and
## and compile the C files, and write both the density matrix and the
## coordinates of the election districts to disk. After the
## transformation we will delete this folder.
dir.create( "tmp" )
file.copy( c( "../c/main.c", "../c/cart.c", "../c/cart.h",
             "../c/interp.c" ), to = "tmp/" )
setwd( "tmp" )

## Compile the C source. For more detailed information see
## http://www-personal.umich.edu/~mejn/cart/doc/
system2( "gcc", args = "-O -o cart cart.c main.c -lfftw3 -lm" )
system2( "gcc", args = "-O -o interp interp.c" )

## Write the density matrix and the election districts to disk
write( t( density.matrix ), "densityMatrix.dat",
      ncolumns = number.of.grid.points.x )
positions.election.districts.matrix <- as.matrix(
    select( election.districts.df, long, lat ) )
## This is an incredibly inefficient way of reshaping the matrix
## but in order to process the positions as a stream it is necessary.
positions.election.districts <- Reduce(
    c, apply( positions.election.districts.matrix, 1, c ) )
write( positions.election.districts, file = "districts.dat",
      ncolumns = 2 )

## Calculate the transformed density
system2( "./cart",
        args = paste( number.of.grid.points.y,
                     number.of.grid.points.x,
                     "densityMatrix.dat densityTransformed.dat" ) )
## Transform the vertices of the election districts
system2( "cat",
        args = paste( "districts.dat | ./interp",
                     number.of.grid.points.y,
                     number.of.grid.points.x,
                     "densityTransformed.dat > districtsTransformed.dat" ) )

## Import the transformed election district data into R
cartogram.values.c <- read.table( "districtsTransformed.dat",
                                 header = FALSE, row.names = NULL )

## Cleanup
setwd( ".." )
unlink( "tmp" )

###################################################################
######################## Plotting the results #####################
###################################################################

## Combining the results into a data.frame
cartogram.df.R <- data.frame( long = cartogram.values.R[ , 1 ],
                           lat = cartogram.values.R[ , 2 ],
                           group = election.districts.df$group,
                           counts = election.districts.df$counts )
## Combining the results into a data.frame
cartogram.df.c <- data.frame( long = cartogram.values.c[[ 1 ]],
                           lat = cartogram.values.c[[ 2 ]],
                           group = election.districts.df$group,
                           counts = election.districts.df$counts )

## and compare it to the default plot.
plot.total <- data.frame(
    long = c( election.districts.df$long, cartogram.df.R$long,
             cartogram.df.c$long),
    lat = c( election.districts.df$lat, cartogram.df.R$lat,
            cartogram.df.c$lat ),
    counts = c( election.districts.df$counts, rep( cartogram.df.R$counts, 2 ) ),
    group = c( election.districts.df$group, rep( cartogram.df.R$group, 2 ) ),
    type = factor( c( rep( "default", nrow( election.districts.df ) ),
                        rep( "Rcartogram", nrow( cartogram.df.R ) ),
                        rep( "cart c function", nrow( cartogram.df.R ) ) ),
                     levels = c( "default", "Rcartogram", "cart c function" ) ) )

ggplot() + geom_polygon( data = plot.total,
                          aes( x = long, y = lat, group = group,
                              alpha = counts ),
                        colour = "black", fill = "#df0404" ) +
coord_quickmap() + theme_minimal() + xlab( "" ) + ylab( "" ) +
  scale_alpha_continuous( guide = FALSE ) +
  facet_wrap(~ type )

ggsave( "../res/cartogram_newman_die_linke.png" )
