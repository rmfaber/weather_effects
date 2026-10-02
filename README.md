# Weather effects on mode choice

Code and data accompanying the paper:

> Faber, R.M., Jonkeren, O., de Haas, M.C., Molin, E.J.E., Kroesen, M. (2022).
> Inferring modality styles by revealing mode choice heterogeneity in response to weather conditions.
> *Transportation Research Part A: Policy and Practice*, 162, 282-295.
> DOI: [10.1016/j.tra.2022.06.003](https://doi.org/10.1016/j.tra.2022.06.003)

Latent class (3LC) and multinomial logit (MNL) mode choice models estimated with
[Apollo](http://www.apollochoicemodelling.com/). Alternatives: car, public transport, bicycle, walking.
Weather covariates: temperature, wind, rain, global radiation. Year 2017 is held out as validation sample.

## Contents

| Path | Description |
|---|---|
| `Models/MNL_model.R` | Multinomial logit benchmark, estimated on all five waves |
| `Models/3LC_model.R` | Three-class latent class model, estimated on all five waves (as the parameter tables of the paper) |
| `Models/MNL_model_outofsample.R` | MNL estimated on waves 1-4, accuracy on wave 5 (as Table 5 of the paper) |
| `Models/3LC_model_outofsample.R` | Latent class model estimated on waves 1-4, accuracy on wave 5 (as Table 5 of the paper) |
| `Data/weather_effects_mpn.csv` | Trip-level estimation data (anonymised, see below) |
| `Paper/` | The published article (open access, CC BY 4.0) |
| `Output/` | Parameter estimates and iteration logs |
| `renv.lock` | Exact package versions |

## Reproducing

Requires R 4.6.1 (other versions may work).

```r
install.packages("renv")
renv::restore()          # installs the locked package versions
source("Models/MNL_model.R")                # all waves
source("Models/3LC_model.R")                # all waves
source("Models/MNL_model_outofsample.R")    # waves 1-4, hold-out wave 5
source("Models/3LC_model_outofsample.R")    # waves 1-4, hold-out wave 5
```

Run from the project root (the scripts read `Data/` and write to `Output/` relative to it; opening `weather_effects.Rproj` sets this). Model results are written to `Output/` (the `.rds` model objects and `*_output.txt` files are not tracked by git). All scripts begin with
`rm(list = ls())`, so run them in a fresh session. `nCores` in the scripts controls parallelism.

## Data

`Data/weather_effects_mpn.csv` contains one row per trip (46,259 trips, 6,715 respondents, 2013-2017),
derived from the Dutch Mobility Panel (MPN) and linked to weather data. Variables are
travel times (minutes) per mode, scaled trip distance (`AFSTV`), trip purpose, standardised
attitude and weather scores, mode availability dummies and the chosen mode (`CHOICE`: 1 car, 2 PT, 3 bike, 4 walk).

Respondent identifiers were replaced by random integers (`PSEUDO_ID`); they only serve to group
repeated observations of the same person. 

## Differences with the paper

The paper reports two sets of results. The goodness-of-fit and out-of-sample statistics (Table 5) come from
models estimated on waves 1-4 of the MPN (6,434 individuals, 37,896 trips) and tested on wave 5
(2,548 individuals, 8,363 trips); these are reproduced by the `Models/*_outofsample.R` scripts. The parameter tables
(Tables 6-9) come from the latent class model estimated on all five waves (6,715 individuals, 46,259 trips);
these are reproduced by `Models/3LC_model.R`.

**Missing personal characteristics.** The shared data contains no personal characteristics of respondents
(gender, age, employment, education, urbanisation level, e-bike ownership, car ownership, driving licence),
because these could identify individuals. The class-membership function of the latent class model therefore only
contains class-specific constants and the four mode attitudes; the personal characteristics are commented out and
their parameters are fixed at zero. The latent class results are consequently close to, but not identical with,
the paper. The class numbering is the same as in the paper: class 1 is bike + car, class 2 is car mostly and
class 3 is multimodal. Readers who need the personal characteristics can request access to the full
Dutch Mobility Panel data at <https://www.mpndata.nl>.

## License

- Code: MIT, see `LICENSE`.
- Paper (`Paper/`): published open access under [CC BY 4.0](http://creativecommons.org/licenses/by/4.0/), see `Paper/LICENSE.md`.
- Data: see the terms of the original data providers (MPN, <https://www.mpndata.nl>).
