# Estimation on waves 1-4 with wave 5 (2017) as hold-out sample
# Clear memory
rm(list = ls())

# Load libraries
library(tidyverse)
library(apollo)
library(feather)
library(corrr)
library(skimr)

# Initialise code
apollo_initialise()

# Set core controls
apollo_control <- list(
  modelName       = "MPN_3LC_v7_tt",
  modelDescr      = "3LC model version",
  indivID         = "PSEUDO_ID",
  nCores          = 4,
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
  correlate()

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
  correlate()

# Mean travel times, distance and attitudes per year
database |>
  group_by(JAAR) |>
  summarise(
    mean(AUTO_MIN),
    mean(OV_MIN),
    mean(FIETS_MIN),
    mean(LOOP_MIN),
    mean(AFSTV),
    mean(Car_Attitude),
    mean(Train_Attitude),
    mean(Bike_Attitude)
  )

# Split off wave 5 (2017) as hold-out sample
wave5 <- database |>
  filter(JAAR == 2017)

database <- database |>
  filter(JAAR != 2017)

# ################################################################# #
#### DEFINE MODEL PARAMETERS                                     ####
# ################################################################# #

apollo_beta <- c(
  asc_cr_1          =  0.000000,
  asc_pt_1          = -5.620169,
  asc_bc_1          =  4.721443,
  asc_wk_1          =  4.521863,
  asc_cr_2          =  0.000000,
  asc_pt_2          = -7.795419,
  asc_bc_2          =  1.393380,
  asc_wk_2          =  3.118920,
  asc_cr_3          =  0.000000,
  asc_pt_3          = -3.685272,
  asc_bc_3          =  3.085406,
  asc_wk_3          =  6.038730,
  b_tt_cr           = -0.178773,
  b_tt_pt           = -0.118130,
  b_tt_am           =  0.014021,
  b_tt_cr_sqrt      =  1.108058,
  b_tt_pt_sqrt      =  1.371337,
  b_tt_am_sqrt      = -0.865280,
  b_purp_work_cr    =  0.000000,
  b_purp_work_pt    =  1.218444,
  b_purp_work_bc    =  1.508054,
  b_purp_work_wk    = -0.008070,
  b_purp_edu_cr     =  0.000000,
  b_purp_edu_pt     =  3.318081,
  b_purp_edu_bc     =  3.249048,
  b_purp_edu_wk     =  1.361123,
  b_temp_cr_1       =  0.000000,
  b_temp_pt_1       =  0.067803,
  b_temp_bc_1       =  0.100830,
  b_temp_wk_1       =  0.048847,
  b_wind_cr_1       =  0.000000,
  b_wind_pt_1       =  0.009828,
  b_wind_bc_1       = -0.043668,
  b_wind_wk_1       =  0.061817,
  b_ri_cr_1         =  0.000000,
  b_ri_pt_1         =  0.157133,
  b_ri_bc_1         = -0.133819,
  b_ri_wk_1         = -0.089066,
  b_ss_cr_1         =  0.000000,
  b_ss_pt_1         =  0.152124,
  b_ss_bc_1         =  0.110137,
  b_ss_wk_1         =  0.090614,
  b_temp_cr_2       =  0.000000,
  b_temp_pt_2       =  0.101146,
  b_temp_bc_2       =  0.123240,
  b_temp_wk_2       = -0.110617,
  b_wind_cr_2       =  0.000000,
  b_wind_pt_2       =  0.105944,
  b_wind_bc_2       = -0.088511,
  b_wind_wk_2       = -0.084278,
  b_ri_cr_2         =  0.000000,
  b_ri_pt_2         = -0.048181,
  b_ri_bc_2         = -0.073155,
  b_ri_wk_2         =  0.017857,
  b_ss_cr_2         =  0.000000,
  b_ss_pt_2         = -0.119329,
  b_ss_bc_2         =  0.052619,
  b_ss_wk_2         =  0.138420,
  b_temp_cr_3       =  0.000000,
  b_temp_pt_3       = -0.131787,
  b_temp_bc_3       =  0.389229,
  b_temp_wk_3       =  0.162371,
  b_wind_cr_3       =  0.000000,
  b_wind_pt_3       =  0.109454,
  b_wind_bc_3       = -0.393722,
  b_wind_wk_3       = -0.276308,
  b_ri_cr_3         =  0.000000,
  b_ri_pt_3         = -0.152604,
  b_ri_bc_3         = -0.141711,
  b_ri_wk_3         = -0.108578,
  b_ss_cr_3         =  0.000000,
  b_ss_pt_3         =  0.057191,
  b_ss_bc_3         =  0.033402,
  b_ss_wk_3         = -0.174331,
  delta_1           =  0.000000,
  delta_2           = -1.175873,
  delta_3           = -3.297564,
  gamma_ebike_2     =  0.000000,
  gamma_male_2      =  0.000000,
  gamma_age_2       =  0.000000,
  gamma_employed_2  =  0.000000,
  gamma_education_2 =  0.000000,
  gamma_density_2   =  0.000000,
  gamma_license_2   =  0.000000,
  gamma_CarAtt_2    = -0.515475,
  gamma_TrainAtt_2  =  0.274453,
  gamma_BTMAtt_2    = -0.130794,
  gamma_BikeAtt_2   =  1.059832,
  gamma_Car_2       =  0.000000,
  gamma_ebike_3     =  0.000000,
  gamma_male_3      =  0.000000,
  gamma_age_3       =  0.000000,
  gamma_employed_3  =  0.000000,
  gamma_education_3 =  0.000000,
  gamma_density_3   =  0.000000,
  gamma_license_3   =  0.000000,
  gamma_CarAtt_3    = -0.407004,
  gamma_TrainAtt_3  =  0.174715,
  gamma_BTMAtt_3    =  0.296930,
  gamma_BikeAtt_3   =  0.336879,
  gamma_Car_3       =  0.000000
)

#' Fix betas of car to get reference alternative
#' But allow flexibility: might set other alternative to ref.
apollo_fixed <- c(
  "delta_1", "b_purp_work_cr", "b_purp_edu_cr",
  "b_temp_cr_1", "b_wind_cr_1", "b_ri_cr_1", "b_ss_cr_1", "asc_cr_1",
  "b_temp_cr_2", "b_wind_cr_2", "b_ri_cr_2", "b_ss_cr_2", "asc_cr_2",
  "b_temp_cr_3", "b_wind_cr_3", "b_ri_cr_3", "b_ss_cr_3", "asc_cr_3",
  "gamma_ebike_2", "gamma_male_2", "gamma_age_2", "gamma_employed_2",
  "gamma_education_2", "gamma_density_2", "gamma_license_2", "gamma_Car_2",
  "gamma_ebike_3", "gamma_male_3", "gamma_age_3", "gamma_employed_3",
  "gamma_education_3", "gamma_density_3", "gamma_license_3", "gamma_Car_3"
)


# ################################################################# #
#### DEFINE LATENT CLASS COMPONENTS                              ####
# ################################################################# #

apollo_lcPars <- function(apollo_beta, apollo_inputs) {
  lcpars <- list()

  lcpars[["asc_cr"]] <- list(asc_cr_1, asc_cr_2, asc_cr_3)
  lcpars[["asc_pt"]] <- list(asc_pt_1, asc_pt_2, asc_pt_3)
  lcpars[["asc_bc"]] <- list(asc_bc_1, asc_bc_2, asc_bc_3)
  lcpars[["asc_wk"]] <- list(asc_wk_1, asc_wk_2, asc_wk_3)

  lcpars[["b_wind_cr"]] <- list(b_wind_cr_1, b_wind_cr_2, b_wind_cr_3)
  lcpars[["b_wind_pt"]] <- list(b_wind_pt_1, b_wind_pt_2, b_wind_pt_3)
  lcpars[["b_wind_bc"]] <- list(b_wind_bc_1, b_wind_bc_2, b_wind_bc_3)
  lcpars[["b_wind_wk"]] <- list(b_wind_wk_1, b_wind_wk_2, b_wind_wk_3)

  lcpars[["b_temp_cr"]] <- list(b_temp_cr_1, b_temp_cr_2, b_temp_cr_3)
  lcpars[["b_temp_pt"]] <- list(b_temp_pt_1, b_temp_pt_2, b_temp_pt_3)
  lcpars[["b_temp_bc"]] <- list(b_temp_bc_1, b_temp_bc_2, b_temp_bc_3)
  lcpars[["b_temp_wk"]] <- list(b_temp_wk_1, b_temp_wk_2, b_temp_wk_3)

  lcpars[["b_ri_cr"]] <- list(b_ri_cr_1, b_ri_cr_2, b_ri_cr_3)
  lcpars[["b_ri_pt"]] <- list(b_ri_pt_1, b_ri_pt_2, b_ri_pt_3)
  lcpars[["b_ri_bc"]] <- list(b_ri_bc_1, b_ri_bc_2, b_ri_bc_3)
  lcpars[["b_ri_wk"]] <- list(b_ri_wk_1, b_ri_wk_2, b_ri_wk_3)

  lcpars[["b_ss_cr"]] <- list(b_ss_cr_1, b_ss_cr_2, b_ss_cr_3)
  lcpars[["b_ss_pt"]] <- list(b_ss_pt_1, b_ss_pt_2, b_ss_pt_3)
  lcpars[["b_ss_bc"]] <- list(b_ss_bc_1, b_ss_bc_2, b_ss_bc_3)
  lcpars[["b_ss_wk"]] <- list(b_ss_wk_1, b_ss_wk_2, b_ss_wk_3)

  V <- list()
  V[["class_1"]] <- delta_1
  V[["class_2"]] <- delta_2 +
    gamma_CarAtt_2 * Car_Attitude + gamma_TrainAtt_2 * Train_Attitude +
    gamma_BikeAtt_2 * Bike_Attitude + gamma_BTMAtt_2 * BTM_Attitude 
    # +
    # gamma_ebike_2 * PEBIKE + gamma_male_2 * Man +
    # gamma_employed_2 * Employed + gamma_density_2 * STED_GM +
    # gamma_license_2 * RIJBEWIJS + gamma_education_2 * OPLEIDING +
    # gamma_Car_2 * PAUTO + gamma_age_2 * KLEEFT2
  V[["class_3"]] <- delta_3 +
    gamma_CarAtt_3 * Car_Attitude + gamma_TrainAtt_3 * Train_Attitude +
    gamma_BikeAtt_3 * Bike_Attitude + gamma_BTMAtt_3 * BTM_Attitude
    # gamma_ebike_3 * PEBIKE + gamma_male_3 * Man +
    # gamma_employed_3 * Employed + gamma_density_3 * STED_GM +
    # gamma_license_3 * RIJBEWIJS + gamma_education_3 * OPLEIDING  +
    # gamma_Car_3 * PAUTO + gamma_age_3 * KLEEFT2

  mnl_settings <- list(
    alternatives = c(class_1 = 1, class_2 = 1, class_3 = 1),
    avail        = 1,
    choiceVar    = NA,
    V            = V
  )
  lcpars[["pi_values"]] <- apollo_mnl(mnl_settings, functionality = "raw")

  lcpars[["pi_values"]] <- apollo_firstRow(lcpars[["pi_values"]], apollo_inputs)

  return(lcpars)
}

# ################################################################# #
#### GROUP AND VALIDATE INPUTS                                   ####
# ################################################################# #

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

  ## Define settings for MNL model
  mnl_settings <- list(
    alternatives = c(cr = 1, pt = 2, bc = 3, wk = 4),
    avail        = list(cr = Car_CS, pt = PT_CS, bc = Bike_CS, wk = Walk_CS),
    choiceVar    = CHOICE
  )

  ## Loop over classes
  s <- 1
  while (s <= 3) {
    ## Compute class-specific utilities
    V <- list()
    V[["cr"]] <- asc_cr[[s]] + b_tt_cr * AUTO_MIN +
      b_tt_cr_sqrt * sqrt(AUTO_MIN) +
      b_purp_work_cr * Purpose_Work + b_purp_edu_cr * Purpose_School +
      b_temp_cr[[s]] * T_DRYB_10_weighted_mean +
      b_wind_cr[[s]] * FF_SENSOR_10_weighted_mean +
      b_ri_cr[[s]] * RI_REGENM_10_weighted_mean +
      b_ss_cr[[s]] * Q_GLOB_10_weighted_mean
    V[["pt"]] <- asc_pt[[s]] + b_tt_pt * OV_MIN +
      b_tt_pt_sqrt * sqrt(OV_MIN) +
      b_purp_work_pt * Purpose_Work + b_purp_edu_pt * Purpose_School +
      b_temp_pt[[s]] * T_DRYB_10_weighted_mean +
      b_wind_pt[[s]] * FF_SENSOR_10_weighted_mean +
      b_ri_pt[[s]] * RI_REGENM_10_weighted_mean +
      b_ss_pt[[s]] * Q_GLOB_10_weighted_mean
    V[["bc"]] <- asc_bc[[s]] + b_tt_am * FIETS_MIN +
      b_tt_am_sqrt * sqrt(FIETS_MIN) +
      b_purp_work_bc * Purpose_Work + b_purp_edu_bc * Purpose_School +
      b_temp_bc[[s]] * T_DRYB_10_weighted_mean +
      b_wind_bc[[s]] * FF_SENSOR_10_weighted_mean +
      b_ri_bc[[s]] * RI_REGENM_10_weighted_mean +
      b_ss_bc[[s]] * Q_GLOB_10_weighted_mean
    V[["wk"]] <- asc_wk[[s]] + b_tt_am * LOOP_MIN +
      b_tt_am_sqrt * sqrt(LOOP_MIN) +
      b_purp_work_wk * Purpose_Work + b_purp_edu_wk * Purpose_School +
      b_temp_wk[[s]] * T_DRYB_10_weighted_mean +
      b_wind_wk[[s]] * FF_SENSOR_10_weighted_mean +
      b_ri_wk[[s]] * RI_REGENM_10_weighted_mean +
      b_ss_wk[[s]] * Q_GLOB_10_weighted_mean

    mnl_settings$V <- V

    ## Compute within-class choice probabilities using MNL model
    P[[paste0("Class_", s)]] <- apollo_mnl(mnl_settings, functionality)

    ## Take product across observations for the same individual
    P[[paste0("Class_", s)]] <- apollo_panelProd(
      P[[paste0("Class_", s)]], apollo_inputs, functionality
    )

    s <- s + 1
  }

  ## Compute latent class model probabilities
  lc_settings <- list(inClassProb = P, classProb = pi_values)
  P[["model"]] <- apollo_lc(lc_settings, apollo_inputs, functionality)

  ## Prepare and return outputs of function
  P <- apollo_prepareProb(P, apollo_inputs, functionality)

  return(P)
}

# ################################################################# #
#### MODEL ESTIMATION                                            ####
# ################################################################# #

default <- list(
  nCandidates = 20, apolloBetaMin = apollo_beta - 1,
  apolloBetaMax = apollo_beta + 1, smartStart = FALSE, maxStages = 5,
  dTest = 1, gTest = 10^-3, llTest = 3, bfgsIter = 20
)

# apollo_beta <- apollo_searchStart(
#   apollo_beta, apollo_fixed, apollo_probabilities, apollo_inputs,
#   searchStart_settings = default
# )

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
  inner_join(forecast$model, by = c("ID", "Observation"))
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
