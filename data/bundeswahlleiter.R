#!/usr/bin/R

## This script will download, collect, and tidy all the data
## provided by www.bundeswahlleiter.de

## Loading require packages
library( tidyr )
library( dplyr )
library( tibble )
library( ggplot2 )
library( readr )
library( stringr )

####################################################################
##################### Download the provided data ###################
####################################################################
## Save all data in a separate folder (within the current one)
download.folder <- "bundeswahlleiter_test/"
if ( !dir.exists( download.folder ) ){
  dir.create( download.folder )
}
## URL pointing to the file containing the results for all of Germany
data.germany.url <- "https://www.bundeswahlleiter.de/dam/jcr/72f186bb-aa56-47d3-b24c-6a46f5de22d0/btw17_kerg.csv"
## URL pointing to the zip file containing the results for the
## individual Wahlbezirke
data.wahlbezirke.url <- "https://www.bundeswahlleiter.de/dam/jcr/ce2d2b6a-f211-4355-8eea-355c98cd4e47/btw_kerg.zip"

## Download
download.file( url = data.germany.url,
              destfile = paste0( download.folder, "btw17_kerg.csv" ),
              method = "wget" )
download.file( url = data.wahlbezirke.url,
              destfile = paste0( download.folder, "btw_kerg.zip" ),
              method = "wget" )
## Extract the data for the Wahlkreise
unzip( paste0( download.folder, "btw_kerg.zip" ),
      exdir = download.folder )


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
  data.pure <- read_delim( path.csv, delim = ";",
                          col_types = cols( .default = col_integer(),
                                           X2 = col_character() ),
                          col_names = FALSE, skip = 5 )
  ## There are a bunch of error messages for the command above. But the
  ## as far as I can tell all the data is present.
  
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

  ## Now we can assign the column names to our data.
  colnames( data.pure ) <- data.header.combined

  ## As an intermediate step we gather all the integer data in the
  ## different columns into one with an additional column holding
  ## the key to the corresponding value.
  ## See http://r4ds.had.co.nz/tidy-data.html#gathering for the
  ## concept of gathering.
  data.gathered <- gather( data.pure,
                          4 : length( data.header.combined ),
                          key = "county_type-of-vote_confirmation-status",
                          value = "counts" )

  ## In the step we will separate the combined attributes across
  ## three different columns.
  ## See http://r4ds.had.co.nz/tidy-data.html#separate for the
  ## concept of separating.
  data.separated <- separate( data.gathered,
                             `county_type-of-vote_confirmation-status`,
                             into = c( "county", "type-of-vote",
                                      "confirmation-status" ),
                             sep = "_" )

}
