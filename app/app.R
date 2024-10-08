library(shiny)
library(leaflet)
library(shinydashboard)
library(scales)
library(shinyWidgets)
library(httr)
library(jsonlite)
library(dplyr)
library(flexdashboard)

source("functions/stations.R")
source("functions/logic.R")

station_choices <- c("All" = "all", setNames(names(stations), sapply(stations, function(station) station$name)))

# Define UI
ui <- dashboardPage(
  title = "Tarspot Forecasting App",
  
  dashboardHeader(
    titleWidth = 450
  ) |> tagAppendChild(
    div(
      "Tarspot Forecasting App",
      style = "
      display: block;
      font-size: 1.5em;
      margin-block-start: 0.5em;
      font-weight: bold;
      color: white;
      margin-right: 50%",
      align = "right"
    ),
    .cssSelector = "nav"
  ),
  
  dashboardSidebar(
    width = 350,
    
    # Custom CSS for controlling appearance
    tags$style(HTML(".js-irs-0 .irs-single,
                    .js-irs-0 .irs-bar-edge,
                    .js-irs-0 .irs-bar {background: #006939},
                    .skin-blue .main-header .logo {
                              background-color: #006939;
                    }
                    .skin-blue .main-header .navbar .sidebar-toggle:hover {
                              background-color: #006939;
                    }
                    .logo {background-color: #006939 !important;}
                    .navbar {background-color: #006939 !important;}")),
    
    sidebarMenu(
      h2(strong(HTML("&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Crop Characteristics")), style = "font-size:18px;"),
      selectInput("custom_station_code", "Please Select a Station", 
                  choices = station_choices),
      selectInput("fungicide_applied", "Did you apply fungicide in the last 14 days?", 
                  choices = c("Yes", "No")),
      selectInput("crop_growth_stage", "What is the growth stage of your crop?", 
                  choices = c("V10-V15", "R1", "R2", "R3"))
    )
  ),
  
  dashboardBody(
    fluidRow(
      # Add a box for the Risk Gauge
      conditionalPanel(
        condition = "input.custom_station_code != 'all' && input.fungicide_applied == 'No'",  # Refined condition
        box(
          h2(strong("Tarspot Risk"), style = "font-size:18px;"),
          gaugeOutput("gauge"),
          width = 12  # Full width for visibility
        )
      )
    ),
    fluidRow(
      box(
        leafletOutput("mymap", height = "600px"),
        width = 12
      )
    ),
    fluidRow(
      box(
        textOutput("station_info"),
        tableOutput("weather_data"),  # Output to show weather data
        width = 12
      )
    )
  )
)

# Define server logic
server <- function(input, output, session) {
  
  # Reactive expression to get the selected station data or all stations
  selected_station_data <- reactive({
    station_code <- input$custom_station_code
    if (station_code == "all") {
      return(stations)  # Return all stations if "All" is selected
    } else {
      return(list(station_code = stations[[station_code]]))  # Return the selected station as a named list
    }
  })
  
  # Fetch station weather data and risk probability when a station is selected
  weather_data <- reactive({
    station_code <- input$custom_station_code
    if (station_code != "all") {
      station <- stations[[station_code]]
      # Call the API or function to get the data
      result <- call_tarspot_for_station(station_code)  # Fetch data
      return(result)
    } else {
      return(NULL)
    }
  })
  
  # Render the leaflet map
  output$mymap <- renderLeaflet({
    leaflet() %>% 
      addTiles() %>% 
      setView(lng = -89.758205, lat = 44.769571, zoom = 7)  # Default map view over Wisconsin
  })
  
  # Update the map based on the selected station(s)
  observe({
    station_data <- selected_station_data()
    
    leafletProxy("mymap") %>% clearMarkers()  # Clear previous markers
    
    # Loop through each station and add a marker
    for (station_code in names(station_data)) {
      station <- station_data[[station_code]]
      leafletProxy("mymap") %>% 
        addMarkers(lng = station$longitude, lat = station$latitude,
                   popup = paste0("<strong>", station$name, "</strong><br>",
                                  station$location, "<br>",
                                  "Region: ", station$region, "<br>",
                                  "State: ", station$state))
    }
  })
  
  # Display station info based on the selection
  output$station_info <- renderText({
    station_code <- input$custom_station_code
    if (station_code == "all") {
      return("You have selected all stations. 
             Please select one to see the risk of tarspot. 
             If you have applied a fungicide in the last 14 days to your crop, 
             we can not estimate a probability of tarspot.")
    } else {
      station <- stations[[station_code]]
      paste("You have selected", station$name, "in", station$state)
    }
  })
  
  # Display the fetched weather data in a table
  output$weather_data <- renderTable({
    weather_data()  # Show weather data from API
  })
  
  # Render the gauge based on the risk value from weather_data
  output$gauge <- renderGauge({
    weather <- weather_data()
    if (!is.null(weather)) {
      risk_value <- weather$risk_probability  # Use the actual risk probability from the API
      
      gauge(risk_value, 
            min = 0, 
            max = 100, 
            sectors = gaugeSectors(
              success = c(0, 20),  # Green (below 20)
              warning = c(20, 35),  # Yellow (20 to 35)
              danger = c(35, 100)  # Red (above 35)
            )
      )
    } else {
      gauge(0, min = 0, max = 100)  # Default to 0 if no data available
    }
  })
}

# Run the application
shinyApp(ui = ui, server = server)
