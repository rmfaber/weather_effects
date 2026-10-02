# Estimation on waves 1-4 with wave 5 (2017) as hold-out sample
# Clear memory
rm(list = ls())

# Load libraries
library(apollo)
library(feather)
library(tidyverse)
library(skimr)

# Initialise code
apollo_initialise()

# Set core controls
apollo_control <- list(
  modelName       = "MNL_tt",
  modelDescr      = "MNL model with traveltimes",
  indivID         = "PSEUDO_ID",
  nCores          = 1,
  outputDirectory = "Output"
)

# ################################################################# #
#### LOAD DATA AND APPLY ANY TRANSFORMATIONS                     ####
# ################################################################# #

database <- read.csv("Data/weather_effects_mpn.csv")

# Add short-distance variable
database <- database |>
  mutate(KORTE_AFSTV = ifelse(AFSTV <= 20, 1, 0))

# Adjust travel times and availabilities
database <- database |>
  filter(!(FIETS_MIN == 0 | OV_MIN == 0 | LOOP_MIN == 0 | AUTO_MIN == 0))

database <- database |>
  mutate(
    PT_CS = ifelse(CHOICE == 2, 1, PT_CS),
    AUTO_MIN_2 = AUTO_MIN * AUTO_MIN,
    OV_MIN_2 = OV_MIN * OV_MIN,
    FIETS_MIN_2 = FIETS_MIN * FIETS_MIN,
    LOOP_MIN_2 = LOOP_MIN * LOOP_MIN
  )

database <- database |>
  mutate(
    AUTO_MIN_sqrt = sqrt(AUTO_MIN),
    OV_MIN_sqrt = sqrt(OV_MIN),
    FIETS_MIN_sqrt = sqrt(FIETS_MIN),
    LOOP_MIN_sqrt = sqrt(LOOP_MIN)
  )

# Inspect correlations
database |>
  select(
    AUTO_MIN, OV_MIN, FIETS_MIN, LOOP_MIN, AFSTV,
    AUTO_MIN_sqrt, OV_MIN_sqrt, FIETS_MIN_sqrt, LOOP_MIN_sqrt
  ) |>
  cor()

# Store original variables before standardisation
database <- database |>
  mutate(
    AUTO_MIN_og = AUTO_MIN,
    OV_MIN_og = OV_MIN,
    FIETS_MIN_og = FIETS_MIN,
    LOOP_MIN_og = LOOP_MIN,
    T_DRYB_10_weighted_mean_og = T_DRYB_10_weighted_mean,
    FF_SENSOR_10_weighted_mean_og = FF_SENSOR_10_weighted_mean,
    Q_GLOB_10_weighted_mean_og = Q_GLOB_10_weighted_mean,
    RI_REGENM_10_weighted_mean_og = RI_REGENM_10_weighted_mean
  )

# Standardise variables
database |>
  select(AUTO_MIN, OV_MIN, FIETS_MIN, LOOP_MIN, AFSTV) |>
  skim()

database |>
  select(
    T_DRYB_10_weighted_mean, FF_SENSOR_10_weighted_mean,
    Q_GLOB_10_weighted_mean, RI_REGENM_10_weighted_mean
  ) |>
  skim()

# Standardise weather variables
database <- database |>
  mutate(across(
    c(
      T_DRYB_10_weighted_mean, FF_SENSOR_10_weighted_mean,
      Q_GLOB_10_weighted_mean, RI_REGENM_10_weighted_mean, AFSTV
    ),
    scale
  ))

prop.table(table(database$Purpose_Work, database$Purpose_School))

# Mean travel times and distance per choice
database |>
  group_by(CHOICE) |>
  summarise(
    mean(AUTO_MIN),
    mean(OV_MIN),
    mean(FIETS_MIN),
    mean(LOOP_MIN),
    mean(AFSTV)
  )

database |>
  select(
    AUTO_MIN, OV_MIN, FIETS_MIN, LOOP_MIN, AFSTV,
    T_DRYB_10_weighted_mean, FF_SENSOR_10_weighted_mean,
    Q_GLOB_10_weighted_mean, RI_REGENM_10_weighted_mean
  ) |>
  cor()

# Split off wave 5 (2017) as hold-out sample
wave5 <- database |>
  filter(JAAR == 2017)

database <- database |>
  filter(JAAR != 2017)

# ################################################################# #
#### DEFINE MODEL PARAMETERS                                     ####
# ################################################################# #

apollo_beta <- c(
  asc_cr         =  0.000000,
  asc_pt         = -6.208445,
  asc_bc         =  2.645348,
  asc_wk         =  3.614101,
  b_tt_cr        = -0.144260,
  b_tt_pt        = -0.117304,
  b_tt_am        =  0.009944,
  b_tt_cr_sqrt   =  0.793374,
  b_tt_pt_sqrt   =  1.372544,
  b_tt_am_sqrt   = -0.773005,
  b_purp_work_cr =  0.000000,
  b_purp_work_pt =  0.883557,
  b_purp_work_bc =  1.083164,
  b_purp_work_wk = -0.280118,
  b_purp_edu_cr  =  0.000000,
  b_purp_edu_pt  =  3.179009,
  b_purp_edu_bc  =  3.533841,
  b_purp_edu_wk  =  1.455915,
  b_temp_cr_1    =  0.000000,
  b_temp_pt_1    = -0.070261,
  b_temp_bc_1    =  0.095300,
  b_temp_wk_1    =  0.011832,
  b_wind_cr_1    =  0.000000,
  b_wind_pt_1    =  0.147381,
  b_wind_bc_1    = -0.119205,
  b_wind_wk_1    = -0.078137,
  b_ri_cr_1      =  0.000000,
  b_ri_pt_1      =  0.002580,
  b_ri_bc_1      = -0.067714,
  b_ri_wk_1      =  0.008712,
  b_ss_cr_1      =  0.000000,
  b_ss_pt_1      =  0.110786,
  b_ss_bc_1      =  0.105682,
  b_ss_wk_1      =  0.016985
)

#' Fix betas of car to get reference alternative
#' But allow flexibility: might set other alternative to ref.
apollo_fixed <- c(
  "asc_cr", "b_temp_cr_1", "b_wind_cr_1", "b_ri_cr_1", "b_ss_cr_1",
  "b_purp_edu_cr", "b_purp_work_cr"
)

apollo_inputs <- apollo_validateInputs()

# ################################################################# #
#### DEFINE MODEL AND LIKELIHOOD FUNCTION                        ####
# ################################################################# #

apollo_probabilities <- function(apollo_beta, apollo_inputs,
                                 functionality = "estimate") {
  ## Attach inputs / detach after function exit
  apollo_attach(apollo_beta, apollo_inputs)
  on.exit(apollo_detach(apollo_beta, apollo_inputs))

  ## Create list of probabilities P
  P <- list()

  ## List of alternatives
  V <- list()
  V[["cr"]] <- asc_cr + b_tt_cr_sqrt * sqrt(AUTO_MIN) + b_tt_cr * AUTO_MIN +
    b_purp_work_cr * Purpose_Work + b_purp_edu_cr * Purpose_School +
    b_temp_cr_1 * T_DRYB_10_weighted_mean +
    b_wind_cr_1 * FF_SENSOR_10_weighted_mean +
    b_ri_cr_1 * RI_REGENM_10_weighted_mean +
    b_ss_cr_1 * Q_GLOB_10_weighted_mean
  V[["pt"]] <- asc_pt + b_tt_pt_sqrt * sqrt(OV_MIN) + b_tt_pt * OV_MIN +
    b_purp_work_pt * Purpose_Work + b_purp_edu_pt * Purpose_School +
    b_temp_pt_1 * T_DRYB_10_weighted_mean +
    b_wind_pt_1 * FF_SENSOR_10_weighted_mean +
    b_ri_pt_1 * RI_REGENM_10_weighted_mean +
    b_ss_pt_1 * Q_GLOB_10_weighted_mean
  V[["bc"]] <- asc_bc + b_tt_am_sqrt * sqrt(FIETS_MIN) + b_tt_am * FIETS_MIN +
    b_purp_work_bc * Purpose_Work + b_purp_edu_bc * Purpose_School +
    b_temp_bc_1 * T_DRYB_10_weighted_mean +
    b_wind_bc_1 * FF_SENSOR_10_weighted_mean +
    b_ri_bc_1 * RI_REGENM_10_weighted_mean +
    b_ss_bc_1 * Q_GLOB_10_weighted_mean
  V[["wk"]] <- asc_wk + b_tt_am_sqrt * sqrt(LOOP_MIN) + b_tt_am * LOOP_MIN +
    b_purp_work_wk * Purpose_Work + b_purp_edu_wk * Purpose_School +
    b_temp_wk_1 * T_DRYB_10_weighted_mean +
    b_wind_wk_1 * FF_SENSOR_10_weighted_mean +
    b_ri_wk_1 * RI_REGENM_10_weighted_mean +
    b_ss_wk_1 * Q_GLOB_10_weighted_mean

  ## Define settings for MNL model
  mnl_settings <- list(
    alternatives = c(cr = 1, pt = 2, bc = 3, wk = 4),
    avail        = list(cr = Car_CS, pt = PT_CS, bc = Bike_CS, wk = Walk_CS),
    choiceVar    = CHOICE,
    V            = V
  )

  ## Compute MNL probabilities
  P[["model"]] <- apollo_mnl(mnl_settings, functionality)

  ## Take product across observations for the same individual
  P <- apollo_panelProd(P, apollo_inputs, functionality)

  ## Prepare and return outputs of function
  P <- apollo_prepareProb(P, apollo_inputs, functionality)

  return(P)
}

# ################################################################# #
#### MODEL ESTIMATION                                            ####
# ################################################################# #

model <- apollo_estimate(
  apollo_beta, apollo_fixed, apollo_probabilities, apollo_inputs
)

## Model outputs
apollo_modelOutput(model)

## Formatted output
apollo_saveOutput(model)

# ################################################################# #
#### ACCURACY ON HOLD-OUT SAMPLE                                 ####
# ################################################################# #

database <- wave5

apollo_inputs <- apollo_validateInputs()

forecast <- apollo_prediction(model, apollo_probabilities, apollo_inputs)

# apollo_prediction() returns the probability of each alternative per trip;
# match these to the observed choices and take the probability of the chosen one
holdout <- database |>
  group_by(PSEUDO_ID) |>
  mutate(Observation = row_number()) |>
  ungroup() |>
  select(ID = PSEUDO_ID, Observation, CHOICE) |>
  inner_join(forecast, by = c("ID", "Observation"))
stopifnot(nrow(holdout) == nrow(database))

prob_chosen <- as.matrix(holdout[, c("cr", "pt", "bc", "wk")])[
  cbind(seq_len(nrow(holdout)), holdout$CHOICE)
]
predicted <- max.col(holdout[, c("cr", "pt", "bc", "wk")], ties.method = "first")

mean(prob_chosen)
sum(log(prob_chosen))
sum(log(prob_chosen)) / nrow(holdout)

table(holdout$CHOICE, predicted)
hit <- sum(predicted == holdout$CHOICE)
hit / nrow(holdout)
