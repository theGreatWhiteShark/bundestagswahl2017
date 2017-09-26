#!/usr/bin/R

## This script will download, collect, and tidy all the data
## provided by www.bundeswahlleiter.de

## Loading require packages for the import and cleaning of the data
library( tidyr )
library( dplyr )
library( tibble )
library( readr )
library( stringr )
## Packages required to handle the shape polygons and to plot the
## results. Be sure to have the packages 'geos', 'geos-devel',
## and 'gdal' installed on your system.
library( rgdal )
library( maptools )
library( ggplot2 )


####################################################################
##################### Download the provided data ###################
####################################################################
## Save all data in a separate folder (within the current one)
download.folder <- "bundeswahlleiter/"
if ( !dir.exists( download.folder ) ){
  dir.create( download.folder )
}
## URL pointing to the file containing the results for all of Germany.
data.election.url <-
  "https://www.bundeswahlleiter.de/dam/jcr/72f186bb-aa56-47d3-b24c-6a46f5de22d0/btw17_kerg.csv"
## Download
download.file( url = data.election.url,
              destfile = paste0( download.folder, "btw17_kerg.csv" ),
              method = "wget" )

### To use the results of the previous runs just uncomment the
### following lines.
## URL pointing to the zip file containing the results of the
## previous elections.
## data.previous.url <-
##   "https://www.bundeswahlleiter.de/dam/jcr/ce2d2b6a-f211-4355-8eea-355c98cd4e47/btw_kerg.zip"
## Download
## download.file( url = data.previous.url,
##               destfile = paste0( download.folder, "btw_kerg.zip" ),
##               method = "wget" )
## Extract the data for the election districts
## unzip( paste0( download.folder, "btw_kerg.zip" ),
##       exdir = download.folder )


####################################################################
################## Tidy the provided data ##########################
####################################################################
## This function requires a string containing the path to a .csv
## file provided by bundeswahlleiter.de and extracts and cleans its
## content.
tidy.data <- function( path.csv ){
  ## The keys of the individual columns are provided in a hierarchical
  ## structure. Therefore they can not be simply read from the file
  ## but have to be added by hand.
  ##
  ## This function is tailored to work with the 2017 election results.
  ## Files for previous runs feature a slightly different header.
  ## Therefore some tiny adjustments to the data import are necessary,
  ## which I will implement later on.
  suppressWarnings(
      data.pure <- read_delim( path.csv, delim = ";",
                              col_types = cols( .default = col_integer(),
                                               X2 = col_character() ),
                              col_names = FALSE, skip = 5 ) )
      
  ## There are a bunch of error messages for the command above. But the
  ## as far as I can tell all the data is present.

  ## There are some rows in the original data featuring only one single
  ## semicolon. Thus they result in a row consisting of only NA entries.
  ## These have to be removed.
  ## Each election districts must have a unique name and a (unfortunately
  ## not unique) number. So we will use these first two columns to search
  ## for the NA rows. If there is an inconsistency, we want the function
  ## to stop and report about it.
  data.pure.na.row.1 <- which( is.na( data.pure[[ 1 ]] ) )
  data.pure.na.row.2 <- which( is.na( data.pure[[ 2 ]] ) )
  if ( !all( data.pure.na.row.1 == data.pure.na.row.2 ) ){
    stop( "tidy.data: There is a inconsistency in the rows containing only NA entries" )
  }
  data.pure <- data.pure[ -data.pure.na.row.1, ]
  
  ## In addition we have to extract all the strings composing the
  ## header in order to correlate it with the individual columns.
  data.header <- readLines( path.csv, n = 5 )

  ## Combining the hierarchical header structure into a single key per
  ## column.
  data.header.1 <- str_split( data.header[ 3 ], pattern = ";" )[[ 1 ]]
  data.header.2 <- str_split( data.header[ 4 ], pattern = ";" )[[ 1 ]]
  data.header.3 <- str_split( data.header[ 5 ], pattern = ";" )[[ 1 ]]

  ## The headers on the higher levels (1 and 2) of the hierarchy leave
  ## the key to a column empty whenever it holds the same string as the
  ## previous one. Therefore we have to fill the gaps.
  fill.header <- function( string.vector ){
    for ( ll in 2 : length( string.vector ) ){
      if ( string.vector[ ll ] == "" ){
        ## Check whether the previous entry contains a string. We will
        ## only fill the vector in downward direction.
        if ( string.vector[ ll - 1 ] != "" ){
          string.vector[ ll ] <- string.vector[ ll - 1 ]
        }
      }
    }
    ## The last column is an artifact
    string.vector[ length( string.vector ) ] <- "NA"
    return( string.vector )
  }
  data.header.1.filled <- fill.header( data.header.1 )
  data.header.2.filled <- fill.header( data.header.2 )
  data.header.3.filled <- fill.header( data.header.3 )
  data.header.combined <- str_c( data.header.1.filled,
                                data.header.2.filled,
                                data.header.3.filled, sep = '_' )

  ## Adjusting the first three elements (those, which won't be
  ## touched during the following reordering)
  data.header.combined[ 1 ] <- "election.district.number"
  data.header.combined[ 2 ] <- "election.district.name"
  data.header.combined[ 3 ] <- "county.number"

  ## Now we can assign the column names to our data.
  colnames( data.pure ) <- data.header.combined

  ## As an intermediate step we gather all the integer data in the
  ## different columns into one with an additional column holding
  ## the key to the corresponding value.
  ## See http://r4ds.had.co.nz/tidy-data.html#gathering for the
  ## concept of gathering.
  data.gathered <- gather( data.pure,
                          4 : length( data.header.combined ),
                          key = "party_type.of.vote_confirmation.status",
                          value = "counts" )

  ## In the step we will separate the combined attributes across
  ## three different columns.
  ## See http://r4ds.had.co.nz/tidy-data.html#separate for the
  ## concept of separating.
  data.separated <- separate( data.gathered,
                             `party_type.of.vote_confirmation.status`,
                             into = c( "party", "type.of.vote",
                                      "confirmation.status" ),
                             sep = "_" )

  ## You can check the validity of the results by comparing all data
  ## of one election district against the row in the corresponding
  ## .csv file.
  ## filter( data.separated, election.district.name ==
  ##                         data.separated$election.district.name[ 1 ]
  ##        )$counts

  ## But be careful about the encoding here! At least for me entering
  ## the district's name by hand doesn't work for all of the them.
  ## data.separated$election.district.name[1] == "Flensburg - Schleswig"
  ## [1] FALSE
  ## This is caused by a different 'minus sign' in the data.
  ## data.separated$election.district.name[1] == "Flensburg – Schleswig"
  ## [1] TRUE
  ## They appear to be identically but they are not!
  ## charToRaw(data.separated$election.district.name[1])
  ## [1] 46 6c 65 6e 73 62 75 72 67 20 e2 80 93 20 53 63 68 6c 65 73 77 69 67
  ## charToRaw("Flensburg - Schleswig")
  ## [1] 46 6c 65 6e 73 62 75 72 67 20 2d 20 53 63 68 6c 65 73 77 69 67

  ## This is probably the case since I'm using a Linux machine and the
  ## document seems to be written in a Windows-based environment.
  ## guess_encoding( charToRaw( str_c( data.separated$election.district.name,
  ##                                  collapse = "" ) ) )
  ##   encoding confidence
  ##          <chr>      <dbl>
  ## 1        UTF-8        1.0
  ## 2 windows-1252        0.3

  ## But most importantly the values match and the tidying is
  ## complete.

  return( data.separated )
}

## Extract and tidy data from all files available.
files.all <- paste0( download.folder, list.files( download.folder ) )
## We only need the .csv files.
files.csv <- files.all[ !is.na( str_match( files.all, ".csv" ) ) ]

## For now let's just work with the results of the current election
file.2017 <- files.csv[ !is.na( str_match( files.csv, "btw17" ) ) ]

## Extract the results and save them to a file.
current.election <- tidy.data( file.2017 )
save( current.election, file = paste0( download.folder,
                                      "current_election.RData" ) )

####################################################################
##################### Shapes of the election districts #############
####################################################################
## This URL contains all the geographical information.
election.districts.url <- "https://www.bundeswahlleiter.de/dam/jcr/f92e42fa-44f1-47e5-b775-924926b34268/btw17_geometrie_wahlkreise_geo_shp.zip"
## For convenience reason let's split the URL at all '/'. This way
## we can directly access the file name.
## Download
election.districts.url.split <- str_split(
    election.districts.url, "/" )
download.file( url = election.districts.url,
              destfile = paste0( download.folder,
                                election.districts.url.split[ 7 ] ),
              method = "wget" )
## Extract the data for the election districts
unzip( paste0( download.folder, election.districts.url.split[ 7 ] ),
      exdir = download.folder )

## Import all the spatial information into one single data object.

## https://github.com/tidyverse/ggplot2/wiki/plotting-polygon-shapefiles
election.districts <- readOGR( dsn = paste0( download.folder, "." ),
                              layer = "Geometrie_Wahlkreise_19DBT_geo" )
## If you want to access content of the spatial object 'election.districts'
## you have to use the '@' symbol. This is necessary since the 'rgdal'
## packages uses the more strict (and oldschool) S4 object class for its
## implementation. See http://adv-r.had.co.nz/OO-essentials.html#s4

## Converting the spatial object into a data.frame better suited
## for the 'ggplot2' package.
election.districts.df <- fortify( election.districts )

## Convert the IDs of the polygons to the same key used to
## identify the election districts.
election.districts.df$election.district.number <-
  as.numeric( election.districts.df$id ) + 1

## Exclude the counties (since they cause the
## election.district.number to be not unique )
current.election.no.counties <- filter( current.election,
                                       county.number != 99 )

## The amount of 2nd votes for the leftists (die Linke)
counts.leftists.second.vote <-
  filter( current.election.no.counties,
         confirmation.status == "Vorläufig" &
         type.of.vote == "Zweitstimmen",
         party == "DIE LINKE" )

## Select just the 'election.district.number' key and the
## 'counts' value (number of votes)
counts.leftists.second.vote <- select(
    counts.leftists.second.vote, election.district.number,
    counts )

## Add the counts to all points of the corresponding polygons
election.districts.df <- left_join( election.districts.df,
                                   counts.leftists.second.vote,
                                   by ="election.district.number")

## 'coord_quickmap()' ensures the axis to be of the right ratio
## to prevent a stretching of the displayed map.

ggplot() + geom_polygon( data = election.districts.df,
                        aes( x = long, y = lat, group = group,
                            alpha = counts ),
                        color = 'black', fill = '#df0404' ) +
coord_quickmap() + theme_minimal() + xlab( "" ) + ylab( "" ) +
  scale_alpha_continuous( guide = FALSE )
ggsave( "../res/leftists-second-vote.png" )  

## Better use 'ggmap' instead of 'ggplot2'
## https://github.com/dkahle/ggmap
## But I have to fork and fix the 'maps' package first.
