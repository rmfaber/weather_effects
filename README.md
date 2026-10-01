# Weather effects on mode choice

Latent class (3LC) and multinomial logit (MNL) mode choice models estimated with
[Apollo](http://www.apollochoicemodelling.com/). Alternatives: car, public transport, bicycle, walking.
Weather covariates: temperature, wind, rain, global radiation. Year 2017 is held out as validation sample.

## Contents

| Path | Description |
|---|---|
| `MNL_model.R` | Multinomial logit benchmark |
| `3LC_model.R` | Three-class latent class model, estimation and hold-out accuracy |
| `Data/weather_effects_mpn.csv` | Trip-level estimation data (anonymised, see below) |
| `Output/` | Parameter estimates and iteration logs |
| `renv.lock` | Exact package versions |

## Reproducing

Requires R 4.6.1 (other versions may work).

```r
install.packages("renv")
renv::restore()          # installs the locked package versions
source("MNL_model.R")
source("3LC_model.R")
```

Run from the project root. Model results are written to `Output/`. Both scripts begin with
`rm(list = ls())`, so run them in a fresh session. `nCores` in the scripts controls parallelism.

## Data

`Data/weather_effects_mpn.csv` contains one row per trip (46,259 trips, 6,715 respondents, 2013-2017),
derived from the Dutch Mobility Panel (MPN) and linked to weather data. Variables are
travel times (minutes) per mode, scaled trip distance (`AFSTV`), trip purpose, standardised
attitude and weather scores, mode availability dummies and the chosen mode (`CHOICE`: 1 car, 2 PT, 3 bike, 4 walk).

Respondent identifiers were replaced by random integers (`PSEUDO_ID`); they only serve to group
repeated observations of the same person. No dates, locations or other direct identifiers are included.

## License

Code: MIT, see `LICENSE`. Data: see the terms of the original data providers.
