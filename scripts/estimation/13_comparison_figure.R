# Comparison figure: Original vs Replication vs Extension ----

source("scripts/project_init.R")

fig_dir <- "output/figures"
tab_dir <- "output/tables"
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)

# Coefficient data ----
# Original paper: Klingen & van Ommeren (2020), Table 6 equivalents
# Replication and extension: current results from scripts 08-11

coefs <- data.table(
  strategy = factor(rep(c("Within-day", "Spatio-temporal", "Cyclist panel"), each = 3),
                    levels = c("Within-day", "Spatio-temporal", "Cyclist panel")),
  sample = factor(rep(c("Original (2013-2017)", "Replication (2013-2017)", "Extension (2013-2025)"), 3),
                  levels = c("Original (2013-2017)", "Replication (2013-2017)", "Extension (2013-2025)")),
  # Replication and extension: run of 2026-11-11 (true clock times; panel of year-month sets, classic bikes)
  coef = c(
    # Within-day (table2_within_day_combined, cols 1-2)
    -0.053, -0.047, -0.057,
    # Spatio-temporal (zone-week FE; table3_spatiotemporal, cols 2 and 4)
    -0.044, -0.049, -0.075,
    # Cyclist panel (d>=0, t>=4; table4_panel_combined, cols 1 and 3)
    -0.026, -0.014, -0.009
  ),
  se = c(
    # Within-day
    0.016, 0.011, 0.011,
    # Spatio-temporal
    0.050, 0.046, 0.028,
    # Cyclist panel
    0.005, 0.003, 0.002
  )
)

coefs[, ci_lo := coef - 1.96 * se]
coefs[, ci_hi := coef + 1.96 * se]

# Color palette ----
cols <- c("Original (2013-2017)" = "#404040",
          "Replication (2013-2017)" = "#2166ac",
          "Extension (2013-2025)" = "#b2182b")

# Plot ----
p <- ggplot(coefs, aes(x = strategy, y = coef, color = sample, shape = sample)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray60", linewidth = 0.4) +
  geom_pointrange(aes(ymin = ci_lo, ymax = ci_hi),
                  position = position_dodge(width = 0.6),
                  size = 0.5, linewidth = 0.7) +
  scale_color_manual(values = cols) +
  scale_shape_manual(values = c(15, 16, 17)) +
  labs(x = NULL,
       y = "Effect on cycling speed (km/h per 10 ppb ozone)",
       color = NULL, shape = NULL) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "bottom",
    legend.margin = margin(t = -5),
    panel.grid.major.x = element_blank(),
    panel.grid.minor = element_blank(),
    axis.text.x = element_text(size = 10),
    plot.margin = margin(10, 15, 5, 10)
  )

# Save as PDF and PNG ----
pdf(file.path(fig_dir, "comparison_coefficients.pdf"), width = 8, height = 4.5)
print(p)
dev.off()

png(file.path(fig_dir, "comparison_coefficients.png"), width = 1600, height = 900, res = 200)
print(p)
dev.off()

cat("Saved comparison_coefficients.pdf and .png\n")

# Save comparison table as CSV ----
summary_tab <- coefs[, .(strategy, sample, coef, se, ci_lo, ci_hi)]
fwrite(summary_tab, file.path(tab_dir, "comparison_summary.csv"))
cat("Saved comparison_summary.csv\n")
