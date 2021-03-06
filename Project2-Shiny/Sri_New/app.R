library(shiny)
library(shinydashboard)
library(googleVis)
require(datasets)
library(plotly)
library(dplyr)
library(sp)
library(rgdal)
library(dplyr)
library(deldir)
library(leaflet)
library(rgeos)
library(htmltools)
library(maps)
library(geosphere)
require(RCurl)
library(DT)
library(reshape2)
library(stringr)


# Choropleth Data 
world1 <- read.csv("world.csv", stringsAsFactors = F)
pass <- read.csv("passenger_tots.csv", stringsAsFactors = F)
#population <- read.csv("~admin/Datasets/populations.csv", stringsAsFactors = F)
colnames(pass)[2] = "CODE"
world1 <- left_join(world1, pass, by = "CODE")
# colnames(world1)[3] = "CODE"
# colnames(population)[1] = "CODE"
#world1 <- inner_join(world1, population, by = "CODE")
world1$X2014.log <- log(world1$X2014)
l <- list(color = toRGB("grey"), width = 0.5)
g <- list(
    showframe = FALSE,
    showcoastlines = TRUE,
    projection = list(type = 'Mercator'))

airlines_by_day <- read.csv("ONTIME_by_day.csv", stringsAsFactors = F)
airlines_by_day <- group_by(airlines_by_day, DAY_OF_MONTH, FLIGHTS) %>% summarise(count=sum(FLIGHTS))
# 
# ##### NEW CALENDAR DATA
f2007_summarised <- read.csv("f2007_summarised.csv")
f2007_summarised[,2] <- as.Date(f2007_summarised$date)

f2006_summarised <- read.csv("f2006_summarised.csv")
f2006_summarised[,2] <- as.Date(f2006_summarised$date)


f2005_summarised <- read.csv("f2005_summarised.csv")
f2005_summarised[,2] <- as.Date(f2005_summarised$date)

f2004_summarised <- read.csv("f2004_summarised.csv")
f2004_summarised[,2] <- as.Date(f2004_summarised$date)

flights_by_day <- rbind(f2007_summarised,f2006_summarised,f2005_summarised,f2004_summarised)

f2007_carrier <- read.csv("f2007_carrier.csv")
f2007_2 <- read.csv("f2007_2.csv")
flights_by_year <- read.csv("flights_by_year.csv")
flights_by_year <- flights_by_year[,2:4]

# 
# # US Airport Data
flights <- read.csv("flights (1).csv", stringsAsFactors = F)
airports <- read.csv("airports (1).csv", stringsAsFactors = F)

airports <- filter(airports, iata %in% union(flights$origin, flights$destination))
orig <- select(count(flights, origin), iata=origin, n1=n)
dest <- select(count(flights, destination), iata=destination, n2=n)
airports <- left_join(airports, select(mutate(left_join(orig, dest),tot=n1+n2),iata, tot)) %>% 
    filter(!is.na(tot))

major <- read.csv("major.csv", stringsAsFactors = F)
dat_con <- getURL("https://raw.githubusercontent.com/jpatokal/openflights/master/data/airports.dat")
airport <- read.csv(textConnection(dat_con), header = F, stringsAsFactors=F)[,-1]
names(airport) <- c("Name", "City", "Country", "FAA", "ICAO", 
                    "lat", "lng", "alti", "timezone", "DST", "tzdb")

airlines.2 <- read.csv("airlines.2.csv", stringsAsFactors = F)
colnames(airlines.2)[8] <- "DEST STATE"
# 
vor_pts <- SpatialPointsDataFrame(cbind(airports$longitude,airports$latitude),airports, match.ID=TRUE)

voronoi <- function(sp) {
    # xtracts polygon data using deldir computation
    vor_desc <- tile.list(deldir(sp@coords[,1], sp@coords[,2]))
    lapply(1:(length(vor_desc)), function(i) {
        
        # link points to make polygons
        tmp <- cbind(vor_desc[[i]]$x, vor_desc[[i]]$y)
        tmp <- rbind(tmp, tmp[1,])
        
        # make the polygons
        Polygons(list(Polygon(tmp)), ID=i)
        
    }) -> vor_polygons
    
    sp_dat <- sp@data
    
    rownames(sp_dat) <- sapply(slot(SpatialPolygons(vor_polygons),'polygons'), slot, 'ID')
    
    SpatialPolygonsDataFrame(SpatialPolygons(vor_polygons),data=sp_dat)
}

vor <- voronoi(vor_pts)
vor_df <- fortify(vor)
states <- map_data("state")
fill <- "state_lines.json"
states <- readOGR("state_lines.json", 
                  "OGRGeoJSON", verbose=FALSE)
states <- subset(states, !NAME %in% c("Alaska", "Hawaii", "Puerto Rico"))
dat <- states@data
states <- SpatialPolygonsDataFrame(gSimplify(states, 0.05,topologyPreserve=TRUE),dat, FALSE)
routes <- list()

## MOTION CHART DATA
pop <- read.csv("pop_tots.csv", stringsAsFactors = F)
passenger <- read.csv("passenger_tots.csv", stringsAsFactors = F)
gdp <- read.csv("gdp_totals.csv", stringsAsFactors = F)

pop <- melt(pop, id=c("Country.Name","Country"))
str_sub(pop$variable, 1,1)  <- ''

passenger <- melt(passenger, id=c("Country.Name","Country"))
str_sub(passenger$variable, 1,1)  <- ''
gdp <- melt(gdp, id=c("Country.Name","Country"))
str_sub(gdp$variable, 1,1)  <- ''

country <- inner_join(pop,passenger, by = c("Country.Name","Country","variable"))
country <- inner_join(country,gdp, by = c("Country.Name","Country","variable"))
names(country) <- c("Country.Name","Country","Year",'Population','Passenger','GDP')

to_delete = country$Country %in% c("HIC","WLD","OED","OEC","NAC","EMU","LMC","LAC",
                                   "SSA","SAS","MRT","MWI","GAB","BFA","ISL","PRY",
                                   "JOR","NPL","CRI","BOL","MDG","SLV","PAN","CMR",
                                   "TTO","JAM","TUN","SEN","LUX","SGP")
country_subset = country[!to_delete,]
country_subset$Year<- as.numeric(country_subset$Year)


### PLOTTING ###

ui <- dashboardPage(
    dashboardHeader(title = "Airport Dashboard"),
    dashboardSidebar(
        sidebarUserPanel(name = "Sricharan Maddineni", image = "http://2igww43ul7xe3nor5h2ah1yq.wpengine.netdna-cdn.com/wp-content/uploads/2016/02/Sri3-300x300.jpg"),
        sidebarMenu(
            menuItem("Home", tabName = "home", icon = icon("home")),
            menuItem("Connections", tabName = "connections", icon = icon("plane")),
            menuItem("Bubble Chart", tabName = "bubble", icon = icon("circle")),
            menuItem("Calendar", tabName = "calendar", icon = icon("calendar")),
            menuItem("Map", tabName = "map", icon = icon("map")),
        menuItem("Appendix", icon = icon("folder"), 
        menuSubItem("Data", tabName = "data"),
        menuSubItem("Libraries", tabName = "libraries")))
    ),
    
    dashboardBody(
        tabItems(
            tabItem(tabName = "home", 
                    div(style = 'overflow-y: scroll',
                    mainPanel(
                    box(h1("Why are Airports so Important?"),
                    h3(),
                    h4("Aviation connects people and goods in almost every corner of the world."),
                    h3(),
                    h4("Today's global connectedness has a profound impact on economic and cultural growth.
                      Airports are the main instruments through which this global connectedness takes shape."),
                    h3(),
                    h4(tags$b("Over one billion people were transported through the air in 2014!")),
                    h3(),
                    h4("The world's busiest airport is HartsfieldJackson Atlanta International Airport in the 
                       United States. More than 88 million passengers traveled through ATL in 2009 alone,
                       with aircrafts taking-off or landing every 37 seconds."),
                    h4("America’s air infrastructure rank has dropped to 30th out of 144 nations over the last decade,
                       and the FAA pegged this cost to the national economy at $21.9 billion. 
                       Projections show this will rise to $34 billion by 2020."),
                    h2(""),
                    tags$blockquote('"I believe that every single American is in the transportation business." - Bill Shuster (Chairman United States House Committee on Transportation and Infrastructure)'),
                    h5(""), 
                    img(src="http://i.imgur.com/7ZPAavl.gif", style="max-width: 100%; max-height: 100%"),
                    width = 12)))),
            tabItem(tabName = "connections",
                    h2("US Airport Connections"),
                    fluidRow(
                        box(leafletOutput("connections"), width=12, height="100%")
                    ),
                   fluidRow(
                       box(width = 8, status = "info", solidHeader = TRUE,
                           title = "Choose Airport",
                           selectInput("Input1", "",
                                       choices = c('Los Angeles International'='LAX','San Diego International' = 'SAN','San Francisco International'='SFO',
                                                   'Seattle–Tacoma International'='SEA', 'Salt Lake City International' = 'SLC', 'John F Kennedy International'='JFK','Newark International'='EWR',
                                                   'Philadelphia International'='PHL', 'Boston Logan International'='BOS', 'Miami International'='MIA',
                                                   'Denver International'='DEN', 'McCarran International' = 'LAS', 'Phoenix Sky Harbor International' = 'PHX',
                                                   'Atlanta International'='ATL', 'Chicago O\'Hare International'='ORD',
                                                   'Dulles International'='IAD','Washington Reagan National' = 'DCA', 'Charlotte Douglas International' = 'CLT'
                                                   ))),
                       valueBoxOutput("count")
                   ),
                   fluidRow(
                       box(width = 8, status = "info", solidHeader = F,
                           title = "Airport Connections", DT::dataTableOutput("table")),
                       box(width = 4, status = "info", solidHeader = F,
                               title = "Carriers", DT::dataTableOutput("table2")))
            ),
            tabItem(tabName = "bubble",
                    h2("Airline Passengers vs Population"),
                    fluidRow(
                        box(htmlOutput("bubble"), width=12)),
                    sliderInput("range", "Range:",
                                min = 1, max = 1330000000, value = c(1,1330000000)),
                    h3("What we see:"),
                    tags$ol(
                        tags$li(h4("Developing countries populations are increasing 
                       at a far greater rate than their airline passenger count.
                                   We can see that their GDP's remain fairly stagnant as well.")), 
                        tags$li(h4("First world countries (US, EU, etc) show the opposite trend.
                       Populations remain constant but drastic increase in 
                                   airline passenger count and GDP.")), 
                        tags$li(h4("During years 2000 and 2009, the stock market crash results in decreased
                       passenger counts - rebound after markets recover.")))
            ),
            tabItem(tabName = "map",
                    fluidRow(
                        headerPanel("Airline Passenger Density by Country"),
                        box(plotlyOutput("map"), width = 12))
            ),
            tabItem(tabName = "calendar",
                    h2("Total Flight Count per Day"),
                    h3(" >> Click on a day to see flight counts by Carrier"),
                    fluidRow(
                        box(htmlOutput("calendar"), width = 12, margin = 2)),
                    h3("Notice:"),
                    tags$ol(
                        tags$li(h4("Airlines have fewer departures on Saturdays and national holidays - 
                       mainly Thanksgiving, July 4th, Christmas, and Memorial Day Weekend.")), 
                        tags$li(h4("Looking closely, you can see that Tuesdays and Wednesdays have fewer departures.")), 
                        tags$li(h4("June, July and August have more departures."))
                    ),
                    br(),
                    fluidRow(
                            valueBoxOutput("date"),
                            box(width = 12, status = "primary", solidHeader = F,
                               title = "Flights On that Day", DT::dataTableOutput("flights"))
                    )
            ),
            tabItem(tabName = "data",
                    div(style = 'overflow-x: scroll'),
                    mainPanel(
                        h2("Datasets"),
                        h3(),
                        h4("The raw data can be downloaded here"),
                        h3(),
                        p(a("faa.gov/data_research", 
                            href = "https://www.faa.gov/data_research/")),
                        p(a("Comprehensive Airline and Airport Data by Month, Year, or Day",
                            href = "http://www.transtats.bts.gov/Fields.asp?Table_ID=258")),
                        h4("The fields I selected are black"),
                        p(a("Airport-Codes-mapped-to-Latitude-Longitude",
                            href = "https://opendata.socrata.com/dataset/Airport-Codes-mapped-to-Latitude-Longitude-in-the-/rxrh-4cxm")),
                        p(a("Comprehensive Airline Routes Data",
                            href = "https://datahub.io/dataset/open-flights/resource/dcaa55bd-6a97-4d6e-9f29-4c32f468af8e")),
                        p(a("Yearly GDP by Country from 1970-present",
                            href = "http://data.worldbank.org/indicator/NY.GDP.MKTP.CD")),
                        p(a("Yearly Population Totals by Country from 1970-present",
                            href = "http://data.worldbank.org/indicator/SP.POP.TOTL")),
                        p(a("Yearly Passenger Count by Country from 1970-present",
                            href = "http://data.worldbank.org/indicator/IS.AIR.PSGR"))
                        )),
            tabItem(tabName = "libraries",
                    div(style = 'overflow-x: scroll'),
                    mainPanel(
                        h3("Libraries"),
                        h3(),
                        h5("library(reshape2)"),
                        h5("library(stringr)"),
                        h5("library(RCurl)"),
                        h5("library(leaflet)"),
                        h5("library(googleVis)"),
                        h5("library(plotly)"),
                        h5("library(deldir)"),
                        h5("library(htmltools)"),
                        h5("library(sp)"),
                        h5("library(rgdal)"),
                        h5("library(DT)"),
                        h5("library(rgeos)"),
                        h5("library(geosphere)"),
                        h5("library(maps)")
                        ))
    )
), skin = "black")


server <- function(input, output) {
    
    updateInputDataForMapTable <- reactive({
        data_filtered <- country_subset %>% filter(country_subset$Population < input$range[2])
    })
    
    output$bubble <- renderGvis({
        
        gvisMotionChart(updateInputDataForMapTable(), 
                        idvar="Country.Name",
                        timevar="Year")
        
    })

    output$map <- renderPlotly({
        plot_ly(world1, z = world1$X2014.log, locations = CODE, type = 'choropleth',
                color = world1$X2014, colors = 'Blues', marker = list(line = l),
                colorbar = list(title = 'Density Scale')) %>%
            layout(geo = g)
    })
    
    output$table <- DT::renderDataTable(DT::datatable({
        data <- airlines.2[,-c(1,2,4,6,9)]
        data <- filter(data, data$ORIGIN == input$Input1)
        data
    }))
    
    output$table2 <- DT::renderDataTable(DT::datatable({
        data <- airlines.2[,-c(1,2,4,6,9)]
        data <- filter(data, data$ORIGIN == input$Input1) %>% group_by(CARRIER) %>% summarise(total=sum(count))
        data
    }, options = list(searching=F)))
    
    output$connections <- renderLeaflet({
        
        JFK_lat <- airport$lat[airport$FAA == input$Input1]
        JFK_lng <- airport$lng[airport$FAA == input$Input1]
        
        airport <- filter(airport, Country=="United States")
        airport <- inner_join(airport, major, by="Name")
        
        for(i in 1:nrow(airport)) {
            if(airport$Country[i] == "United States" & airport$FAA[i] != input$Input1) {
                route <- gcIntermediate(c(JFK_lng, JFK_lat), 
                                        c(airport$lng[i], airport$lat[i]),
                                        n = 200, addStartEnd = TRUE)
                route <- as.data.frame(route)
                if(!is.null(route))
                    routes[[length(routes)+1]] <- route
            }
        }
        
        addRoutes <- function(map, x, ...) {
            for(i in 1:length(x)) {
                tryCatch(map <- addPolylines(map, lat = x[[i]]$lat, lng = x[[i]]$lon, ...),
                         error = function(e) map,
                         finally = map)
                
            }
            return(map)
        }
        
        addRoutes(
            
            leaflet(width=900, height=650) %>% 
                setView(lng = -95.72, lat = 37.13, zoom = 4) %>%
                addProviderTiles("NASAGIBS.ViirsEarthAtNight2012",
                                 options = providerTileOptions(opacity = 1)) %>%
                addPolygons(data=states,
                            stroke=TRUE, color="#C0C0C0", weight=1, opacity=.70,
                            fill=TRUE, fillColor="#303030", smoothFactor=0.5) %>%
                addPolygons(data=vor,
                            stroke=TRUE, color="#00BFFF", weight=.50,
                            fill=TRUE, fillOpacity = 0.0,
                            smoothFactor=1, 
                            popup=sprintf((vor@data$name))) %>%
                addCircles(data=arrange(airports, desc(tot)),
                           lng=~longitude, lat=~latitude,
                           radius=~sqrt(tot)*5000,
                           color="white", weight=1, opacity=1,
                           fillColor="steelblue", fillOpacity=1
                           )
            
            
            ,routes, weight = 1, color = "red", opacity = 1)
    })
    
    
    output$count <- renderValueBox({
        valueBox(
            value = airports[airports$iata == input$Input1,]$tot,
            subtitle = "Number of Connections",
            icon = icon("share-alt"),
            color = if (airports[airports$iata == input$Input1,]$tot >= 170) "aqua" else "yellow"
        )
    })

    output$calendar <- renderGvis({
        gvisCalendar(flights_by_day, 
                     datevar="date", 
                     numvar="count",
                     options=list(
                         title="Daily flight count in the United States",
                         height=400,
                         calendar="{yearLabel: { fontName: 'Times-Roman',
                 fontSize: 32, color: '#1A8763', bold: true},
                 cellSize: 10,
                 cellColor: { stroke: 'red', strokeOpacity: 0.2 },
                 focusedCellColor: {stroke:'red'}}",
                         gvis.listener.jscode = "var selected_date = data.getValue(chart.getSelection()[0].row,0);var parsed_date = selected_date.getFullYear()+'-'+(selected_date.getMonth()+1)+'-'+selected_date.getDate();
                         Shiny.onInputChange('selected_date',parsed_date)")
        )
    })
    
flightsOutput <- reactive({
    date <- givs.listener.jscode
    cat(date)
})

output$date <- renderValueBox({
    cat(input$selected_date)
    
    valueBox(
        value = input$selected_date,
        subtitle = "Selected Date",
        icon = icon("eye"))
})

observe(
    if (!is.null(input$selected_date)) {
    output$flights <- DT::renderDataTable(DT::datatable({

        data <- flights_by_year
        data <- filter(data, data$date == input$selected_date)
        data
    }))}
    )
}

shinyApp(ui, server)
