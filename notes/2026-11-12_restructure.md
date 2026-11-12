# Folder restructure (2026-11-12)

The repo follows the hub standard `way_of_work/repo_structure.md`. Older notes quote the
old paths; this is the translation. Scripts kept their numbers.

| Old | New |
|---|---|
| `R/00_packages.R` | `scripts/project_init.R` |
| `R/04_clean_cycling.R` | `scripts/data_management/04_clean_cycling.R` |
| `R/05_clean_environment.R` | `scripts/data_management/05_clean_environment.R` |
| `R/06_merge.R` | `scripts/data_management/06_merge.R` |
| `R/07_descriptives.R` | `scripts/descriptives/07_descriptives.R` |
| `R/08_within_day.R` | `scripts/estimation/08_within_day.R` |
| `R/09_between_day.R` | `scripts/estimation/09_between_day.R` |
| `R/10_spatiotemporal.R` | `scripts/estimation/10_spatiotemporal.R` |
| `R/11a_panel_build.R` | `scripts/estimation/11a_panel_build.R` |
| `R/11b_panel_estimate.R` | `scripts/estimation/11b_panel_estimate.R` |
| `R/12_robustness.R` | `scripts/estimation/12_robustness.R` |
| `R/13_comparison_figure.R` | `scripts/estimation/13_comparison_figure.R` |
| `R/14_nonlinearity_figure.R` | `scripts/estimation/14_nonlinearity_figure.R` |
| `R/15_yearly_effect.R` | `scripts/estimation/15_yearly_effect.R` |
| `R/16_panel_figures.R` | `scripts/estimation/16_panel_figures.R` |
| `2020_version` | `references/2020_version` |
| `data/processed` | `data/sample` |

Path rewrites applied to tracked files outside `notes/` (regular expression, replacement, hits):

- `R/00_packages[.]R` to `scripts/project_init.R`: 15
- `(?<![A-Za-z0-9_./])R/(0[4-6][a-z]?_)` to `scripts/data_management/\1`: 5
- `(?<![A-Za-z0-9_./])R/(07_)` to `scripts/descriptives/\1`: 1
- `(?<![A-Za-z0-9_./])R/(0[89][a-z]?_|1[0-6][a-z]?_)` to `scripts/estimation/\1`: 10
- `(?<![A-Za-z0-9_])data/processed` to `data/sample`: 14
