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
| `MNL_model.R` | Multinomial logit benchmark |
| `3LC_model.R` | Three-class latent class model, estimation and hold-out accuracy |
| `Data/weather_effects_mpn.csv` | Trip-level estimation data (anonymised, see below) |
| `Paper/` | The published article (open access, CC BY 4.0) |
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

## Differences with the paper

The scripts estimate the models on waves 1-4 of the MPN (6,434 individuals, 37,896 trips) and test them
on wave 5 (2,548 individuals, 8,363 trips), as in Table 5 of the paper. The parameter tables in the paper
(Tables 6-9) come from the latent class model re-estimated on all five waves (46,259 trips), which the scripts do not do.

**MNL model (including weather).** `MNL_model.R` reproduces the MNL column of Table 5 of the paper
(log-likelihood -28,102, 27 parameters, AIC 56,258, hold-out hit rate 0.679, hold-out log-likelihood -6,089).

**Latent class model.** The shared data contains no personal characteristics of respondents
(gender, age, employment, education, urbanisation level, e-bike ownership, car ownership, driving licence),
because these could identify individuals. The class-membership function in `3LC_model.R` therefore only
contains class-specific constants and the four mode attitudes; the personal characteristics are commented out and
their parameters are fixed at zero. Results are close to, but not identical with, those in the paper:

| LC model incl. weather | Paper (Table 5) | This repository |
|---|---|---|
| Parameters | 83 | 67 |
| Log-likelihood (waves 1-4) | -23,662 | -24,017 |
| Rho-squared | 0.455 | 0.447 |
| AIC | 47,491 | 48,167 |
| BIC | 48,200 | 48,740 |
| Hold-out hit rate | 0.708 | 0.700 |
| Hold-out mean probability of chosen mode | 0.594 | 0.583 |
| Hold-out log-likelihood | -5,694 | -5,814 |
| Class shares (class 1 / 2 / 3) | 45% / 39% / 16% | 44.5% / 38.0% / 17.5% |

The 16 missing parameters are the eight personal characteristics in each of the two class-membership
equations. Travel time, constant and weather parameters are close to those in Tables 6 and 9 of the paper
(the paper's estimates are from all five waves). The class numbering is the same as in the paper:
class 1 is bike + car, class 2 is car mostly and class 3 is multimodal.

Readers who need the personal characteristics can request access to the full Dutch Mobility Panel data at
<https://www.mpndata.nl>.

## License

- Code: MIT, see `LICENSE`.
- Paper (`Paper/`): published open access under [CC BY 4.0](http://creativecommons.org/licenses/by/4.0/), see `Paper/LICENSE.md`.
- Data: see the terms of the original data providers (MPN, <https://www.mpndata.nl>).
