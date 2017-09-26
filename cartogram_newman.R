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
############ Calculating and plotting the cartogram ###############
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

## Calculating the new coordinates for the vertices in the
## cartogram.
cartogram.values <- predict( density.cartogram,
                            election.districts.df$long,
                            election.districts.df$lat )
## Combining the results into a data.frame
cartogram.df <- data.frame( long = cartogram.values[ , 1 ],
                           lat = cartogram.values[ , 2 ],
                           group = election.districts.df$group,
                           counts = election.districts.df$counts )

## and compare it to the default plot.
plot.total <- data.frame(
    long = c( election.districts.df$long, cartogram.df$long ),
    lat = c( election.districts.df$lat, cartogram.df$lat ),
    counts = c( election.districts.df$counts, cartogram.df$counts ),
    group = c( election.districts.df$group, cartogram.df$group ),
    type = factor( c( rep( "default", nrow( election.districts.df ) ),
                        rep( "cartogram", nrow( cartogram.df ) ) ),
                     levels = c( "default", "cartogram" ) ) )

ggplot() + geom_polygon( data = plot.total,
                          aes( x = long, y = lat, group = group,
                              alpha = counts ),
                        colour = "black", fill = "#df0404" ) +
coord_quickmap() + theme_minimal() + xlab( "" ) + ylab( "" ) +
  scale_alpha_continuous( guide = FALSE ) +
  facet_wrap(~ type )
ggsave( "res/cartogram_newman_die_linke.png" )
