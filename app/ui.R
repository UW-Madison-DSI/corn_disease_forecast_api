library(shiny)
library(leaflet)
library(httr)
library(jsonlite)
library(dplyr)
library(leaflet.extras)
library(httr)
library(tigris)
library(sf)
options(tigris_use_cache = TRUE)
library(DT)
library(shinyWidgets)

source("functions/5_instructions.R")

logo_src = "logos/uw-logo-horizontal-color-web-digital.svg"
tool_title <- "Agricultural Forecasting and Advisory System"

# UI 
ui <- navbarPage(
  title = tool_title,
  theme = shinythemes::shinytheme("flatly"), 
  footer = div(class = "footer-text", "© 2024 UW-Madison"),
  
  # Tab 1: Weather Map
  tabPanel(
    "Disease Forecasting",
    sidebarLayout(
      sidebarPanel(
        style = "height: 800px;",
        div(
          class = "logo-container",
          tags$img(
            src = logo_src,
            style = "max-width: 500px; max-height: 100px; display: block; margin: 10px auto;" # Limit height
          )
        ),
        hr(),
        switchInput(
          inputId = "ibm_data", 
          label = "Pin my location", 
          onLabel = "ON", 
          offLabel = "OFF", 
          value = FALSE
        ),
        hr(),
        conditionalPanel(
          condition = "input.ibm_data == false",  # Condition to display disease selection
          selectInput(
            "disease_name",
            "Select Disease:",
            choices = c(
              "Tar Spot (Corn)" = 'tarspot',
              "Gray Leaf Spot (Corn)" = 'gls',
              "Frogeye Leaf Spot (Soybean)" = 'fe',
              "Whitemold Irr (30in)" = 'whitemold_irr_30in',
              "Whitemold Irr (15in)" = 'whitemold_irr_15in',
              "Whitemold Dry" = 'whitemold_nirr'
            )
          )
        ),
        dateInput(
          "forecasting_date",
          "Select Forecasting Date:",
          value = Sys.Date(),
          min = '2023-06-01',
          max = Sys.Date()
        ),
        hr(), 
        h4("Crop Management"),
        checkboxInput("no_fungicide", "No fungicide applied in the last 14 days?", value = TRUE),
        
        # Conditional panel for Frogeye Leaf Spot
        conditionalPanel(
          condition = "input.disease_name == 'fe' && input.ibm_data == false",
          checkboxInput("crop_growth_stage", "Growth stage in the R1-R5 range?", value = TRUE),
          sliderInput(
            "risk_threshold",
            "Risk Threshold:",
            min = 40,
            max = 50,
            value = 50,
            step = 1
          ),
          p(
            "This is the recommended threshold risk.",
            style = "font-size: 0.9em; color: #777; font-style: italic; margin-top: 5px; margin-bottom: 5px;"
          )
        ),
        
        # Conditional panel for GLS
        conditionalPanel(
          condition = "input.disease_name == 'gls' && input.ibm_data == false",
          checkboxInput("crop_growth_stage", "Growth stage in the V10-R3 range?", value = TRUE),
          sliderInput(
            "risk_threshold",
            "Risk Threshold:",
            min = 40,
            max = 60,
            value = 60,
            step = 1
          ),
          p(
            "This is the recommended threshold risk.",
            style = "font-size: 0.9em; color: #777; font-style: italic; margin-top: 5px; margin-bottom: 5px;"
          )
        ),
        
        # Conditional panel for Tar Spot
        conditionalPanel(
          condition = "input.disease_name == 'tarspot' && input.ibm_data == false",
          checkboxInput("crop_growth_stage", "Growth stage in the V10-R3 range?", value = TRUE),
          sliderInput(
            "risk_threshold",
            "Risk Threshold:",
            min = 20,
            max = 50,
            value = 35.0,
            step = 1
          ),
          p(
            "This is the recommended threshold risk.",
            style = "font-size: 0.9em; color: #777; font-style: italic; margin-top: 5px; margin-bottom: 5px;"
          )
        ),
        hr(), 
        #conditionalPanel(
        #  condition = "input.ibm_data == false",  # Use lowercase `false` in JavaScript
        #  h4("Map Layers"),
        #  checkboxInput("show_heatmap", "Show Heat Map", value = FALSE)
        #),
        conditionalPanel(
          condition = "input.ibm_data !== false",  # Ensure the condition is checking for exactly 'false'
          actionButton(
            inputId = "run_model", 
            label = "Run Model", 
            class = "btn-success"
          ),
          p(
            "This option provides a summary of all diseases for the selected location and forecasting date.",
            style = "font-size: 0.9em; color: #777; font-style: italic; margin-top: 5px; margin-bottom: 5px;"
          )
        )
      ),
      mainPanel(
        leafletOutput("risk_map", height = 800),
        conditionalPanel(
          condition = "input.ibm_data == false",
          div(
            textOutput("map_info"),
            style = "margin-top: 10px; color: #666;"
          )
        ),
        conditionalPanel(
          condition = "input.ibm_data != false",
          div(
            textOutput('click_coordinates'),
            style = "margin-top: 10px; color: #666;"
          )
        ),
        conditionalPanel(
          condition = "input.ibm_data == false",
          div(
            textOutput("station_count"),
            style = "margin-top: 10px; color: #666; font-size: 14px;"
          )
        )
      )
    )
  ),
  
  # Tab 2: Station Forecasting Risk and Weather Trends
  tabPanel(
    title = "Summary",
    fluidPage(
      h3("Station Summary"),
      mainPanel(
        textOutput('station_specifications'),
        hr(),
        checkboxGroupInput("disease", 
                           label = "Choose Diseases",
                           choices = c("Tar Spot", "Gray Leaf Spot", "Frog Eye Leaf Spot", 
                                       "Whitemold Irr (30in)", "Whitemold Irr (15in)", "Whitemold No Irr"),
                           selected = c("Tar Spot", "Gray Leaf Spot"), inline = TRUE),  # Default selection
        hr(),
        plotOutput("risk_trend", height = "400px", width = "100%"),   
        hr(),
        conditionalPanel(
          condition = "input.ibm_data == false",
          textOutput("download_reported"),
          p("Downloadable summary of risk trend for the given station."),
          div(
            downloadButton("download_report", "Download Report", 
                           class = "btn-primary", 
                           style = "text-align: center; margin-top: 10px;")
          )
        )
      )
    )
  ),
  # Tab 3: Downloads
  tabPanel(
    title = "Downloads",
    fluidPage(
      h3("Downloads"),
      hr(),
      p("A tabular report on weather data and risk estimates for the selected location, such as a specific station or a location pinned on the map."),
      downloadButton("download_stations", "Download csv", 
                     class = "btn-primary", 
                     style = "text-align: center; margin-top: 10px;"),
      #hr(),
      #plotOutput('air_temperature_plot', height = "1200px", width = "100%")
    )
  ),
  
  # Tab 6: About
  tabPanel(
    title = "About",
    about_page
  )
  
)
