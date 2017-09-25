This file contains all the references to the data. 

To save space the data itself won't be present here but just some scripts to download them automatically.

# Data sources
### [bundeswahlleiter.de](https://www.bundeswahlleiter.de/bundestagswahlen/2017.html)
- A **machine-readable** version of the results for [Germany](https://www.bundeswahlleiter.de/dam/jcr/72f186bb-aa56-47d3-b24c-6a46f5de22d0/btw17_kerg.csv). But it's dubbed **preliminary** results. So we have to check the data again at some point.
- A **machine-reabable** version of the results for each [individual Wahlkreis](https://www.bundeswahlleiter.de/dam/jcr/ce2d2b6a-f211-4355-8eea-355c98cd4e47/btw_kerg.zip). This compilation is **not complete yet**! Just some of the Wahlkreise are present.
- Geometrical [shapes](https://www.bundeswahlleiter.de/bundestagswahlen/2017/wahlkreiseinteilung/downloads.html) of the Wahlkreise.
- The [results](https://www.bundeswahlleiter.de/bundestagswahlen/2017/ergebnisse.html) are delivered as County > Wahlkreis > HTML5 table. Could be extracted using [Scrapy](https://scrapy.org/) but most probably all of it's information is already present in the data mentioned above.


### No machine-readable data online
- [https://bundestagswahl-2017.com/](https://bundestagswahl-2017.com/)
  Present all their results using pictures.
- [http://wahlatlas.net/](http://wahlatlas.net/)
  Interactive Leaflet map without an export function for the selected data.
- [http://www.politische-bildung.de/bundestagswahl_2017.html](http://www.politische-bildung.de/bundestagswahl_2017.html#c8650)
  Loads of links to analysis and comments on the election but not to data.
- [http://www.forschungsgruppe.de/Aktuelles/Wahlanalyse_Bundestagswahl](http://www.forschungsgruppe.de/Aktuelles/Wahlanalyse_Bundestagswahl/)
  Just some analysis and PDFs.
- [https://www.bpb.de/politik/wahlen/bundestagswahl-2017/](https://www.bpb.de/politik/wahlen/bundestagswahl-2017/249001/fragen-und-antworten-faq)

# Scripts

The [bundeswahlleiter.R](data/bundeswahlleiter.R) script contains some R code to download and tidy the data provided by the [bundeswahlleiter.de](https://www.bundeswahlleiter.de/bundestagswahlen/2017.html) web page.
