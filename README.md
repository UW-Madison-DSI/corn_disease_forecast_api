![R-CMD-check](https://github.com/mariaob1201/corn_disease_forecast_api/actions/workflows/r-cmd-check.yml/badge.svg)

# **Forecasting Model Tools: API and Dashboard**

This API leverages the power of environmental data to predict the likelihood of diseases like Tarspot, Spore and Gray Leaf Spot on corn crops. 

## Features

- Predicts the probability of disease incidence based on key environmental variables.
- Customizable action thresholds that allow users to define risk levels for interventions.
- Returns the probability and risk classification for the given thresholds.

## Dashboard 
Visit our [dashboard here](https://connect.doit.wisc.edu/tarspot_forecasting_app/)

## API Endpoints

**Base URL**: [Forecast Crop Disease API](https://connect.doit.wisc.edu/forecasting_crop_disease/)

### Endpoints:

- `/predict_tarspot_risk`  
  Predicts the probability and risk level for **Tarspot**.

- `/predict_gray_leaf_spot_risk`  
  Predicts the probability and risk level for **Gray Leaf Spot**.

- `/predict_sporecaster_risk`  
  Predicts the probability and risk level for **Spore**.

- `/predict_frogeye_leaf_spot_risk`  
  Predicts the probability and risk level for **Frogeye**.


Method: `POST` 

Response: A JSON object containing the predicted probability of tar spot incidence and the associated risk level.

## To install
```bash
git clone https://github.com/UW-Madison-DSI/corn_disease_forecast_api.git
cd corn_disease_forecast_api
```

## Usage
See example of how to do an api call on this tool [HERE](https://github.com/UW-Madison-DSI/corn_disease_forecast_api/blob/main/materials/example/example_api_call.R)

## Project Structure 
```
├── LICENSE
├── README.md                       <- The top-level README for developers using this project.
├── plumber.R                       <- Logic to create API
├── R                               <- Main functionalities for API
│   ├── crop_mangm_validations.R      <- Crop management validations
│   ├── logit_function.R              <- Core functions for forecasting disease api
│   ├── var_schema.R                  <- Variables schema
├── materials                       <- Examples of API calls and plug in with Wisconet
│   ├── call_wisconet                 <- Wisconet call example
│   ├── docs                          <- Documentation of the schema
│   ├── example                       <- Examples to call the API
├── app                             <- Shinny dashboard code.
│   ├── app.R                         <- app logic, ui and server
│   ├── functions                     <- API functions
│   │   ├── logic.R                       <- Logic to call the Wisconet Station weather data and call the forecasting models on the preparation of the inputs
│   │   ├── stations.R                    <- List of stations currently active from Wisconet  
├── test                            <- Code Testing modules
│   ├── testthat.R    
 ```

## License

This project is licensed under the MIT License - see the LICENSE file for details.


### Acknowledgements
- This work is an Open-Source initiative from the [Open Source Program Office at the University of Madison Wisconsin](https://ospo.wisc.edu), aimed at fostering collaboration and innovation in forecasting tools.
- The models presented are based on plant pathology research in the University of Madison Wisconsin, paper: [Nature Scientific Reports, 2023](https://www.nature.com/articles/s41598-023-44338-6)
- This software was created by the [Data Science Institute](https://datascience.wisc.edu) at the [University of Wisconsin-Madison](https://www.wisc.edu)

Mantainer: Maria Oros, maria.oros@wisc.edu

