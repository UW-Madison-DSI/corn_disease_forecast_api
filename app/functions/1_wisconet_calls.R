################################################################################
############      Main function on All Wisconet Stations Forecasting Data    ############
################################################################################
library(httr2)
library(jsonlite)
library(dplyr)

url_all_stations_api <- "https://connect.doit.wisc.edu/pywisconet_wrapper/ag_models_wrappers/wisconet?forecasting_date=%s&risk_days=%s"
popup_content_str <- "<strong>Station:</strong> %s<br><strong>Location:</strong> %s <br><strong>Region:</strong> %s<br><strong>Forecasting Date:</strong> %s<br><strong>Risk Models</strong><br><strong>Tarspot:</strong> %.2f%%<br><strong>Frogeye Leaf Spot:</strong> %.2f%%<br><strong>Gray Leaf Spot:</strong> %.2f%%<br><strong>Whitemold Dry:</strong> %.2f%%<br><strong>Whitemold Irrigation (30in):</strong> %.2f%%<br><strong>Whitemold Irrigation (15in):</strong> %.2f%%"



fetch_forecasting_data <- function(date) {
  tryCatch({
    # Construct the API URL
    start_time <- Sys.time()
    cat("API call started at:", start_time, "\n")
    
    api_url <- sprintf(url_all_stations_api, date, 7) # retrieve 7 days historical data
    
    # Make the GET request
    response <- request(api_url) %>%
      req_headers("Content-Type" = "application/json") %>%
      req_perform()
    
    # Parse the JSON response
    response_content <- resp_body_json(response, simplifyVector = TRUE)
    end_time1 <- Sys.time()
    
    cat("Time taken for API call response before turned it as tabular:", end_time1 - start_time, "\n")
    if (is.null(response_content) || length(response_content) == 0) {
      stop("No stations_risk data in API response")
    }
    
    stations_df <- bind_rows(response_content)
    print(head(stations_df))
    
    stations_df <- stations_df %>%
      mutate(
        forecasting_date = as.Date(date)+1,
        popup_content = sprintf(
          popup_content_str,
          station_name,
          location,
          region,
          forecasting_date,
          tarspot_risk * 100,
          fe_risk * 100,
          gls_risk * 100,
          whitemold_nirr_risk * 100,
          whitemold_irr_30in_risk * 100,
          whitemold_irr_15in_risk * 100
        )
      )
    
    end_time <- Sys.time()
    
    cat("Time taken for API call complete:", end_time - start_time, "\n")
    return(stations_df)
  
  }, error = function(e) {
    message(paste0("Error processing data: ", e$message))
    return(NULL)
  })
}
