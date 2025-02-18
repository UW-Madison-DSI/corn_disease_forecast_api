library(shiny)
library(leaflet)
library(httr)
library(jsonlite)
library(dplyr)
library(leaflet.extras)
library(tigris)
library(sf)
options(tigris_use_cache = TRUE)
library(DT)
library(gridExtra)
library(reshape2)
library(httr2)

source("functions/1_wisconet_calls.R")
source("functions/2_external_source.R")

source("functions/3_weather_plots.R") #now only on the risk trend but about to be on the weather data
source("functions/4_pdf_template.R")

source("functions/7_data_transformations.R")


########################################################## SETTINGS: WI boundary
county_boundaries <- counties(state = "WI", cb = TRUE, class = "sf") %>%
  st_transform(crs = 4326)

wi_boundary <- states(cb = TRUE) %>%
  filter(NAME == "Wisconsin") %>%
  st_transform(4326)

wisconsin_bbox <- list(
  lat_min = 42.4919,
  lat_max = 47.3025,
  lng_min = -92.8894,
  lng_max = -86.2495
)




######################################################################## SERVER
server <- function(input, output, session) {
  
  # Initialize shared_data with reactive values
  shared_data <- reactiveValues(
    w_station_id = NULL,
    run_model = NULL,
    lat_location = NULL,
    lng_location = NULL,
    ibm_data = NULL,
    disease_name = 'tarspot',
    stations_data = fetch_forecasting_data(Sys.Date()),
    nstations = 58,
    this_station_data = fetch_forecasting_data(Sys.Date())%>%filter(station_id=='ALTN'), #default if not specified
    start_time = Sys.time()
  )
  
  forecast_data <- reactive({
    # This will re-run only when input$forecasting_date changes.
    fetch_forecasting_data(input$forecasting_date)
  })
  
  observeEvent(input$info_icon, {
    # Toggle the visibility of the tooltip
    toggle("info_tooltip")
  })
  
  
  ############################################################################## IBM data, AOI: Wisconsin
  # Add a marker on user click
  observeEvent(input$risk_map_click, {
    click <- input$risk_map_click
    
    if (!is.null(click) && (input$ibm_data == TRUE)) {
      # Gather the coordinates
      shared_data$lat_location <- click$lat
      shared_data$lng_location <- click$lng
      # Check if the click is inside Wisconsin
      inside_wisconsin <- click$lat >= wisconsin_bbox$lat_min &&
        click$lat <= wisconsin_bbox$lat_max &&
        click$lng >= wisconsin_bbox$lng_min &&
        click$lng <= wisconsin_bbox$lng_max
      
      if (!inside_wisconsin) {
        showNotification(
          "You clicked outside Wisconsin. Please click within the state boundary.",
          type = "warning"
        )
      } else {
        # Add a marker at the clicked location
        leafletProxy("risk_map") %>%
          clearMarkers() %>%
          clearShapes() %>% # Clear existing shapes to avoid overlaps
          addMarkers(
            lng = click$lng,
            lat = click$lat,
            popup = paste("Latitude:", round(click$lat, 4), "<br>Longitude:", round(click$lng, 4))
          ) %>%
          addPolygons(
            data = wi_boundary,
            color = "blue",
            fillColor = "lightblue",
            weight = 2,
            fillOpacity = 0,
            popup = ~NAME
          ) %>%
          setView(lng = click$lng, lat = click$lat, zoom = 12)
      }
    }
  })
  
  ################################################ Punctual estimates, observe clicks, run model IBM
  observeEvent(input$run_model, {
    # Ensure click has occurred and ibm_data is TRUE
    req(!is.null(input$risk_map_click), input$ibm_data)
    shared_data$run_model <- TRUE
    click <- input$risk_map_click
    
    if (!is.null(click$lng)) {
      shared_data$lng_location <- click$lng
      shared_data$lat_location <- click$lat
      
      punctual_estimate <- ibm_query(input$forecasting_date, click$lat, click$lng)
      shared_data$ibm_data <- punctual_estimate
      
      punctual_estimate <- punctual_estimate %>% filter(forecasting_date == as.Date(input$forecasting_date))
      
      # Display the summary of risks for all diseases
      all_risks_text <- paste(
        "Tarspot (Corn) Risk Class: ", punctual_estimate$tarspot_risk_class, "| ",
        "Gray Leaf Spot (Corn) Risk Class: ", punctual_estimate$gls_risk_class, "| ",
        "FrogEye (Soybean) Risk Class: ", punctual_estimate$fe_risk_class, "| ",
        "Whitemold Irrigated (30in) Risk: ", round(punctual_estimate$whitemold_irr_30in_risk * 100, 2), "% | ",
        "Whitemold Irrigated (15in) Risk: ", round(punctual_estimate$whitemold_irr_15in_risk * 100, 2), "% | "
        #"Whitemold Dry Risk: ", round(punctual_estimate$whitemold_nirr_risk * 100, 2), "%"
      )
      
      # Display the clicked coordinates and risk information
      output$click_coordinates <- renderText({
        paste(
          "Clicked Coordinates: Latitude =", round(click$lat, 4),
          ", Longitude =", round(click$lng, 4), "|", 
          " Summary of All Diseases Risk:", all_risks_text
        )
      })
    } else {
      showNotification("Please click on the map for a location within the State of Wisconsin, USA to run the model.", type = "message")
    }
  })
  
  relabeling_class <- function(data, disease, threshold){
    if(disease=='tarspot' && threshold!=.35){
      data$tarspot_risk_class <- if_else(data$tarspot_risk>threshold, "High", data$tarspot_risk_class)
    }
    return(data)
  }
  ################################################################## This is the section 1 risk_map
  output$risk_map <- renderLeaflet({
    if(input$ibm_data==FALSE){
      county_boundaries <- st_transform(county_boundaries, crs = 4326)
      
      data <- forecast_data()
      print(data)
      print(input$forecasting_date)
      lower_b <- 20
      upper_b1 <- (input$risk_threshold_ts)
      if (input$disease_name == 'tarspot' && !input$risk_threshold_ts %in% c(35, NULL)) {
        lower_b <- 20
        upper_b1 <- (input$risk_threshold_ts)
        data <- data %>%
            mutate(tarspot_risk_class = case_when(
              tarspot_risk < lower_b/100 ~ "Low",  
              tarspot_risk > upper_b1/100 ~ "High", 
              TRUE ~ "Moderate" 
            ))
        paste0("Moving the threshold in tarspot ", upper_b1)
      }else if (input$disease_name == 'tarspot' && input$risk_threshold_ts==35) {
        lower_b <- 20
        upper_b1 <- 35
        data <- data %>%
          mutate(tarspot_risk_class = case_when(
            tarspot_risk < lower_b/100 ~ "Low",  
            tarspot_risk > upper_b1/100 ~ "High", 
            TRUE ~ "Moderate" 
          ))
        paste0("Moving the threshold in tarspot ", upper_b1)
      }
        
      if (input$disease_name == 'gls' && !input$risk_threshold_gls %in% c(60, NULL)) {
        lower_b <- 50
        upper_b1 <- (input$risk_threshold_gls)
        data <- data %>%
            mutate(gls_risk_class = case_when(
              gls_risk < lower_b/100 ~ "Low",
              gls_risk > upper_b1/100 ~ "High", 
              TRUE ~ "Moderate"   
          ))
      }else if (input$disease_name == 'gls' && input$risk_threshold_gls==60) {
        lower_b <- 50
        upper_b1 <- 60
        data <- data %>%
          mutate(tarspot_risk_class = case_when(
            tarspot_risk < lower_b/100 ~ "Low",  
            tarspot_risk > upper_b1/100 ~ "High", 
            TRUE ~ "Moderate" 
          ))
        paste0("Moving the threshold in tarspot ", upper_b1)
      }
      
      if (input$disease_name == 'fe' && !input$risk_threshold_fe==50) {
        lower_b <- 40
        upper_b1 <- (input$risk_threshold_fe)
        data <- data %>%
          mutate(fe_risk_class = case_when(
              fe_risk < lower_b/100 ~ "Low",
              fe_risk > upper_b1/100 ~ "High",
              TRUE ~ "Moderate"
          ))
      }else if (input$disease_name == 'fe' && input$risk_threshold_fe==50) {
        lower_b <- 40
        upper_b1 <- 50
        data <- data %>%
          mutate(tarspot_risk_class = case_when(
            tarspot_risk < lower_b/100 ~ "Low",  
            tarspot_risk > upper_b1/100 ~ "High", 
            TRUE ~ "Moderate" 
          ))
        paste0("Moving the threshold in tarspot ", upper_b1)
      }

      upper_b <- upper_b1
      shared_data$stations_data <- data
      end_time_part2 <- Sys.time()
      time_part2 <- end_time_part2 - shared_data$start_time
      
      # Display the results
      cat(paste("Time for Part 1: ", time_part2, " seconds\n"))
      
      # Check if data is available
      if (nrow(data) > 0) {
        data <- data_transform_risk_labels(data, shared_data$disease_name) 
        shared_data$stations_data <- data

        data1 <- shared_data$stations_data %>%
          filter(forecasting_date == input$forecasting_date) %>%
          mutate(`Forecasting Date` = forecasting_date)

        if (input$disease_name %in% c('tarspot','fe','gls')){
          # Create the map and plot the points
          map <- leaflet(data1) %>%
            addProviderTiles(providers$CartoDB.Positron) %>%
            setView(lng = -89.75, lat = 44.76, zoom = 7.2) %>%
            addCircleMarkers(
              lng = ~longitude,  # Longitude column in your data
              lat = ~latitude,   # Latitude column in your data
              popup = ~popup_content,  # Popup content
              color = "black",  # Marker outline color
              fillColor = ~fill_color,  # Fill color based on your `fill_color` column
              fillOpacity = 0.8,  # Opacity of the marker fill
              radius = 6,  # Radius of the marker
              weight = 1.5,  # Border thickness
              label = ~station_name,  # Label on hover (optional)
              labelOptions = labelOptions(
                style = list("font-weight" = "normal", padding = "3px 8px"),
                textsize = "12px", direction = "auto"
              ),
              layerId = ~station_name 
            ) %>%
            addLegend(
              "bottomright",
              colors = c("#88CCEE", "#DDCC77", "#CC6677"),
              labels = c(paste0("Low (≤ ", lower_b, '%)'), 
                         paste0("Moderate (", lower_b, " - ", upper_b1,'%)'), 
                         paste0("High (> ", upper_b1,'%)')),
              title = paste0("Predicted Risk (%)"),
              opacity = 1
            ) 
        }

        risk_variables <- list(
          'whitemold_irr_30in' = 'whitemold_irr_30in_risk',
          'whitemold_irr_15in' = 'whitemold_irr_15in_risk',
          'whitemold_nirr' = 'whitemold_nirr_risk'
        )
        
        # Check if the disease name is in the mapping
        if (input$disease_name %in% names(risk_variables)) {
          # Get the corresponding risk variable for the selected disease
          risk_variable <- risk_variables[[input$disease_name]]
          
          map <- leaflet(data1) %>%
            addProviderTiles(providers$CartoDB.Positron) %>%
            setView(lng = -89.75, lat = 44.76, zoom = 7.2) %>%
            addCircleMarkers(
              lng = ~longitude,
              lat = ~latitude,
              popup = ~popup_content, 
              color = "black",
              fillColor = ~colorNumeric(palette = "YlGnBu", 
                          domain = data1[[risk_variable]])(data1[[risk_variable]]),
              fillOpacity = 0.8,
              radius = 6, 
              weight = 1.5, 
              label = ~station_name,
              labelOptions = labelOptions(
                style = list("font-weight" = "normal", padding = "3px 8px"),
                textsize = "12px", direction = "auto"
              ),
              layerId = ~station_name
            ) %>%
            addLegend(
              position = "bottomright", 
              pal = colorNumeric(palette = "YlGnBu", domain = data1[[risk_variable]]), 
              values = data1[[risk_variable]],
              title = "Risk (%)",  
              opacity = 1 
            )
        }
        
        map %>%
          addPolygons(
            data = county_boundaries,
            color = "gray",
            weight = 1,
            opacity = 1,
            fillOpacity = 0,
            fillColor = "lightpink",
            group = "County Boundaries",
            popup = ~NAME
          ) %>%
          addLayersControl(
            baseGroups = c("CartoDB Positron", "OpenStreetMap", "Topographic", "Esri Imagery"),
            overlayGroups = c("County Boundaries"),
            options = layersControlOptions(collapsed = TRUE)
          ) %>%
          hideGroup("County Boundaries")
      } else {
        # Return a default map if no data is available
        leaflet() %>%
          addProviderTiles(providers$CartoDB.Positron) %>%
          setView(lng = -89.75, lat = 44.76, zoom = 7.2)
      }
    }else{
      map<-leaflet() %>%
        addProviderTiles("CartoDB.Positron", group = "CartoDB Positron") %>%
        addProviderTiles("OpenStreetMap", group = "OpenStreetMap") %>%
        addProviderTiles("USGS.USTopo", group = "Topographic") %>% 
        addProviderTiles("Esri.WorldImagery", group = "Esri Imagery") %>%
        setView(lng = -89.75, lat = 44.76, zoom = 7.2) %>%
        addLayersControl(
          baseGroups = c("OpenStreetMap", "CartoDB Positron","Topographic",  #"Terrain",
                         "Esri Imagery"),
          options = layersControlOptions(collapsed = TRUE)
        )
    }
  })
  
  # Observe click event to center the map on the selected station
  observeEvent(input$risk_map_marker_click, {
    click <- input$risk_map_marker_click
    shared_data$w_station_id<-click$id
    print(click)
    
    this_station <- shared_data$stations_data 
    this_station <- this_station%>% filter(station_name == click$id)
    
    shared_data$this_station_data <- this_station
    if (!is.null(click)) {
      # Update the map view to the clicked location
      leafletProxy("risk_map") %>%
        setView(lng = click$lng, lat = click$lat, zoom = 16) %>%
        addProviderTiles("Esri.WorldImagery", group = "Esri Imagery")
    } else {
      warning("No click event detected.")
    }
  })
  
  observeEvent(c(input$crop_growth_stage, input$no_fungicide),{  # Include inputs to trigger observation
    if (!input$no_fungicide) {
      showNotification(
        paste(
          custom_disease_name(input$disease_name),
          "risk can only be computed if no fungicide was applied in the last 14 days."
        ),
        type = "error"
      )
    } 
    
    if(!input$crop_growth_stage){
      showNotification(
        paste(
          custom_disease_name(input$disease_name),
          "risk can only be computed if the growth stage is as recommended."
        ),
        type = "error"
      )
    }
  })
  
  output$station_specifications <- renderText({
    tryCatch({
      if (!is.null(shared_data$ibm_data)) {
        paste("Given location: Lat ", shared_data$lat_location, ", Lon ", shared_data$lng_location)
      } else if (!is.null(shared_data$w_station_id)){
        data <- shared_data$this_station_data

        # Check if data is not empty
        if (nrow(data) > 0) {
          station <- data$station_name[1]
          earliest_api_date <- data$earliest_api_date[1]
          
          location <- if_else(
            data$location[1] == "Not set",  
            "", 
            paste("situated in", data$location[1], ",", data$region[1], "Region,", data$state[1], ",")
          )
          
          date_obj <- as.Date(earliest_api_date, format = "%Y-%m-%d")  
          # Format for user-friendly reading
          user_friendly_date <- format(date_obj, "%B %d, %Y")
          
          paste(
            station, "Station,", location, "has been operational since", user_friendly_date
          )
          
        } else if ((is.null(shared_data$w_station_id)) && (is.null(shared_data$ibm_data))) {
          "Please select a station by clicking on it in the map from the Disease Forecasting section."
        }
      }
    }, error = function(e) {
      # Handle error
      message("Please select a station by clicking on it in the map from the Disease Forecasting section.")
    })
  })
  
  output$risk_trend <- renderPlot({
    ## Logic to plot the 7 days trend, in this case all the disease modesls are displayed
    data_prepared <- NULL
    location <- NULL
    if (!is.null(shared_data$w_station_id))  {
      data_prepared <- shared_data$this_station_data
      location <- paste0(shared_data$w_station_id, " Station")
    }else if (!is.null(shared_data$ibm_data)) {
      data_prepared <- shared_data$ibm_data
      data_prepared$forecasting_date <- as.Date(data_prepared$forecasting_date, format = '%Y-%m-%d')
      location <- paste0("Lat ", shared_data$latitude, "Lon ", shared_data$longitude)
    }
    
    if (is.null(data_prepared)) {
      plot.new()
      text(0.5, 0.5, "Please select an station in the map first.", cex = 1.5)
    }else{
      selected_diseases <- input$disease
      print(selected_diseases)
      seven_days_trend_plot(data_prepared, location, selected_diseases) 
    }
  })
  
  ############################################################################## This is the section 3 Download a csv with the wisconet Stations data
  output$download_stations <- downloadHandler(
    # Dynamically generate the filename
    filename = function() {
      paste0("Report_", input$disease_name, "_forecasting_", Sys.Date(), ".csv")
    },
    
    content = function(file) {
      # Fetch the data from your reactive function
      data_f <- NULL
      if(input$ibm_data==FALSE){
        data_f <- shared_data$stations_data 
        data_f <- data_f %>%
          select(station_id, date, forecasting_date, location, station_name, 
                 city, county, earliest_api_date, latitude, longitude, region, state, 
                 station_timezone, tarspot_risk, tarspot_risk_class, gls_risk, 
                 gls_risk_class, fe_risk, fe_risk_class, 
                 whitemold_irr_30in_risk, whitemold_irr_15in_risk) %>%
          mutate(across(ends_with("_risk"), ~ . * 100))      
      }else if(input$ibm_data==TRUE){
        if (!is.null(shared_data$ibm_data)) {
          # Query IBM data
          data_f <- shared_data$ibm_data
          data_f$lat <- shared_data$lat_location
          data_f$lng <- shared_data$lng_location
        }
      }
      
      # Validate if data is available for download
      if (!is.null(data_f) && nrow(data_f) > 0) {
        write.csv(data_f, file, row.names = FALSE)
      } else {
        stop("No data available for download.")
      }
    }
  )
  
  ############################################################################## PDF report only for station choice
  output$download_report <- downloadHandler(
    filename = function() {
      req(shared_data$w_station_id, cancelOutput = TRUE)
      paste0("Report_risktrend_uwmadison_",
             output$w_station_id,'_', Sys.Date(), ".pdf")
    },
    content = function(file) {
      data <- shared_data$this_station_data
      location_name <- paste0(data$station_name[1], " Station")
      
      if (is.null(data) || nrow(data) == 0) {
        showNotification("No data available to generate the report.", type = "warning")
        stop("No data available to generate the report.")
      }
      
      data_f <- data %>% select(forecasting_date,
                                tarspot_risk,tarspot_risk_class,
                                gls_risk,gls_risk_class,
                                fe_risk,fe_risk_class,
                                whitemold_irr_30in_risk,whitemold_irr_15in_risk
                                #whitemold_nirr_risk
                                )
      
      report_template<-template_pdf(file)
      
      # Prepare report parameters
      report_params <- list(
        location = location_name,
        #disease = custom_disease_name(input$disease_name),
        forecasting_date = input$forecasting_date,
        fungicide = input$no_fungicide,
        growth_stage = input$crop_growth_stage,
        risk_table = data_f
      )
      
      # Render the report
      tryCatch({
        rmarkdown::render(
          input = report_template,
          output_file = file,
          params = report_params,
          envir = new.env(parent = globalenv()) # To avoid any potential environment issues
        )
      }, error = function(e) {
        showNotification(
          paste("Report generation failed:", e$message), 
          type = "error", 
          duration = 10
        )
        stop(e)
      })
    }
  )
}
