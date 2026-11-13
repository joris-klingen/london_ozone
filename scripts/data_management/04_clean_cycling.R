# Clean cycling trip data — process file-by-file, output year parquets ----

TEST_MODE <- FALSE  # Set TRUE to process only 10 files for debugging

source("scripts/project_init.R")

# Journeys come from the shared London data store (london_transport/data: one parquet per published
# TfL file, one schema for all years); see ../../data_stores/london_transport/london_data_catalog.md
source(file.path(research_path("london_transport"), "R/london_transport.R"))

# CLOCK = "published" reads every published clock time as GMT, as the 2026-03 run did. TfL publishes
# GMT up to the extract ending 2013-09-13 and UK local time from 2013-09-14 on, so in summer those
# journeys sit one hour late against the GMT air quality and weather. CLOCK = "true" uses the
# store's true times instead (start_time, converted to GMT).
CLOCK <- "true"
years_keep <- 2013:2025

out_dir <- "data/sample"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# Helper functions ----

keep_cols <- c("rental_id", "start_station_id", "end_station_id",
               "start_dt", "end_dt", "duration_sec",
               "start_lat", "start_lon", "end_lat", "end_lon",
               "dist_straight_km", "dist_km", "speed_kmh",
               "date", "hour", "dow", "month", "year", "ebike")

# One store file as the columns this script uses: station ids are the BikePoint id up to 2022-09
# and the terminal number after (and in the one 2016 file that gives terminals), as before
read_trips <- function(f) {
  x <- santander_read(files = f, columns = c("rental_id", "duration_s", "start_station_id", "start_terminal",
                                             "end_station_id", "end_terminal", "bike_model"))
  if (CLOCK == "true") {
    st <- lubridate::with_tz(x[, start_time], "GMT")
    en <- lubridate::with_tz(x[, end_time], "GMT")
  } else {
    st <- x[, start_clock]
    en <- x[, end_clock]
    attr(st, "tzone") <- "GMT"
    attr(en, "tzone") <- "GMT"
  }
  dt <- data.table(rental_id = x[, rental_id], start_dt = st, end_dt = en, duration_sec = x[, duration_s],
                   start_station_id = fcoalesce(x[, start_station_id], as.integer(x[, start_terminal])),
                   end_station_id = fcoalesce(x[, end_station_id], as.integer(x[, end_terminal])),
                   # e-bikes exist from 2022-09 (bike_model); NA before, when every bike was classic
                   ebike = x[, bike_model] == "PBSC_EBIKE")
  dt[!is.na(start_dt) & year(start_dt) %in% years_keep]
}

haversine <- function(lat1, lon1, lat2, lon2) {
  R <- 6371
  dlat <- (lat2 - lat1) * pi / 180
  dlon <- (lon2 - lon1) * pi / 180
  a <- sin(dlat / 2)^2 + cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dlon / 2)^2
  2 * R * asin(sqrt(a))
}

# Read station locations ----

# this project's station table (BikePoint 2026-03 plus the station numbers used from 2022-09), in the store
stations <- ozone_stations_read()
setkey(stations, station_id)

# Process files one by one, accumulate into year buckets ----

m <- santander_manifest()[parquet != "" & as.Date(last_start) >= as.Date(sprintf("%d-01-01", min(years_keep))) &
                            as.Date(first_start) <= as.Date(sprintf("%d-12-31", max(years_keep)))]
trip_files <- file.path(santander_dir(), m[, parquet])

if (TEST_MODE) {
  set.seed(42)
  trip_files <- sample(trip_files, min(10, length(trip_files)))
  cat("TEST MODE: processing", length(trip_files), "sampled files\n")
}

cat("Processing", length(trip_files), "trip files...\n")

year_buckets <- list()
file_count <- 0L
skip_count <- 0L

# Flush year buckets to disk to manage memory ----
flush_count <- 0L
flush_buckets <- function() {
  flush_count <<- flush_count + 1L
  for (yr_key in names(year_buckets)) {
    chunk <- rbindlist(year_buckets[[yr_key]], fill = TRUE)
    out_path <- file.path(out_dir, sprintf("trips_%s_part%03d.parquet", yr_key, flush_count))
    write_parquet(chunk, out_path)
  }
  year_buckets <<- list()
  gc(verbose = FALSE)
}

for (f in trip_files) {
  tryCatch({
    dt <- read_trips(f)
    if (nrow(dt) == 0L) next

    # Merge station coordinates (keyed join)
    dt[stations, `:=`(start_lat = i.lat, start_lon = i.lon), on = .(start_station_id = station_id)]
    dt[stations, `:=`(end_lat = i.lat, end_lon = i.lon), on = .(end_station_id = station_id)]

    # Distance and speed (combined)
    dt[, dist_straight_km := haversine(start_lat, start_lon, end_lat, end_lon)]
    dt[, `:=`(dist_km  = dist_straight_km * 1.3,
              speed_kmh = dist_straight_km * 1.3 / (duration_sec / 3600))]

    # Filter
    dt <- dt[!is.na(speed_kmh) & speed_kmh > 0.1 & speed_kmh <= 30 &
               dist_km > 0 & duration_sec > 60]
    if (nrow(dt) == 0L) next

    # Time variables (combined)
    dt[, `:=`(date  = as.Date(start_dt),
              hour  = hour(start_dt),
              dow   = wday(start_dt),
              month = month(start_dt),
              year  = year(start_dt))]

    # Keep only final columns
    out_cols <- intersect(keep_cols, names(dt))
    drop_final <- setdiff(names(dt), out_cols)
    if (length(drop_final)) dt[, (drop_final) := NULL]

    # Append chunks to year bucket lists
    for (y in unique(dt$year)) {
      yr_key <- as.character(y)
      if (is.null(year_buckets[[yr_key]])) year_buckets[[yr_key]] <- list()
      year_buckets[[yr_key]][[length(year_buckets[[yr_key]]) + 1L]] <- dt[year == y]
    }

    file_count <- file_count + 1L
    if (file_count %% 5L == 0L) {
      mem_mb <- round(sum(sapply(year_buckets, function(bl) sum(sapply(bl, object.size)))) / 1e6, 0)
      cat(sprintf("  [%d/%d files | %d skipped | %dMB buffered]\n",
                  file_count, length(trip_files), skip_count, mem_mb))
    }

    # Flush to disk every 100 files to manage memory
    if (file_count %% 100L == 0L) {
      cat("  Flushing year buckets to disk...\n")
      flush_buckets()
    }
  }, error = function(e) {
    cat("  ERROR in", basename(f), ":", conditionMessage(e), "\n")
    skip_count <<- skip_count + 1L
  })
}

cat("Processed", file_count, "files, skipped", skip_count, ".\n")

# Final flush of remaining buckets ----
if (length(year_buckets) > 0L) flush_buckets()

# Combine per-year parts into final year parquets ----

all_parts <- list.files(out_dir, pattern = "^trips_\\d{4}_part\\d+\\.parquet$", full.names = TRUE)
years <- unique(sub("^trips_(\\d{4})_part.*", "\\1", basename(all_parts)))

total <- 0L
for (yr_key in sort(years)) {
  yr_parts <- all_parts[grepl(paste0("trips_", yr_key, "_part"), all_parts)]
  dt <- rbindlist(lapply(yr_parts, function(p) as.data.table(read_parquet(p))), fill = TRUE)
  out_path <- file.path(out_dir, paste0("trips_", yr_key, ".parquet"))
  write_parquet(dt, out_path)
  cat("  trips_", yr_key, ".parquet: ", nrow(dt), " rows\n", sep = "")
  total <- total + nrow(dt)
  file.remove(yr_parts)
  rm(dt); gc(verbose = FALSE)
}

cat("Total cleaned trips:", total, "\n")
