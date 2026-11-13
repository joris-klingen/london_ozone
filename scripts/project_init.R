# Research folder ----
# research_path("nyc_db") finds another repo of the research folder: next to this project, or one
# folder down from the research root (the folder that holds the file .research_root)
research_path <- function(name) {
  root <- normalizePath(".", winslash = "/")
  while (!file.exists(file.path(root, ".research_root")) && dirname(root) != root) root <- dirname(root)
  hit <- Find(dir.exists, c(file.path("..", name), file.path(root, name), Sys.glob(file.path(root, "*", name))))
  if (is.null(hit)) stop("Repo ", name, " not found next to this project or under the research root")
  hit
}

# Install and load required packages ----

pkgs <- c(
  "data.table",
  "arrow",
  "jsonlite",
  "curl",
  "fixest",
  "ggplot2",
  "gridExtra",
  "lubridate",
  "sf",
  "suncalc"
)

for (pkg in pkgs) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    install.packages(pkg, repos = "https://cloud.r-project.org")
  }
  library(pkg, character.only = TRUE)
}

cat("All packages loaded.\n")
