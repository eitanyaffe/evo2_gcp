#!/usr/bin/env Rscript

# Simple R script to plot steering test results
# This script is hardcoded to work with the test_steering example output

library(ggplot2)
library(dplyr)
library(readr)

# hardcoded paths for test_steering example
job_dir <- "jobs/evo-steering-v1/output"
output_dir <- "jobs/evo-steering-v1/plots"

# create output directory
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

cat("plotting steering test results...\n")
cat("job directory:", job_dir, "\n")
cat("output directory:", output_dir, "\n")

# read summary tables for different steering scales
summary_files <- list.files(job_dir, pattern = "*_summary_.*\\.txt$", full.names = TRUE)
cat("found summary files:", length(summary_files), "\n")

if (length(summary_files) == 0) {
  stop("no summary files found in ", job_dir)
}

# read all summary tables
summary_data <- data.frame()
for (file in summary_files) {
  cat("reading:", basename(file), "\n")
  
  # extract steering condition from filename
  if (grepl("unsteered", file)) {
    condition <- "unsteered"
    scale <- 0.0
  } else if (grepl("scale_", file)) {
    scale_match <- regmatches(file, regexpr("scale_[-+]?[0-9]*\\.?[0-9]+", file))
    scale <- as.numeric(gsub("scale_", "", scale_match))
    condition <- paste0("scale_", scale)
  } else {
    condition <- "unknown"
    scale <- NA
  }
  
  # read data
  data <- read_tsv(file, show_col_types = FALSE)
  data$condition <- condition
  data$scale <- scale
  
  summary_data <- rbind(summary_data, data)
}

cat("total rows loaded:", nrow(summary_data), "\n")
cat("conditions found:", paste(unique(summary_data$condition), collapse = ", "), "\n")

# plot 1: log-likelihood comparison across scales
summary_means <- summary_data %>%
  group_by(condition, scale) %>%
  summarise(mean_ll = mean(total_log_likelihood, na.rm = TRUE),
            se_ll = sd(total_log_likelihood, na.rm = TRUE) / sqrt(n()),
            .groups = 'drop')

p1 <- ggplot(summary_means, aes(x = factor(scale), y = mean_ll, fill = condition)) +
  geom_bar(stat = "identity", position = "dodge", alpha = 0.8) +
  geom_errorbar(aes(ymin = mean_ll - se_ll, ymax = mean_ll + se_ll),
                position = position_dodge(width = 0.9), width = 0.25) +
  labs(title = "steering effect on log-likelihood",
       x = "steering scale",
       y = "mean total log-likelihood",
       fill = "condition") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave(file.path(output_dir, "log_likelihood_comparison.png"), p1, 
       width = 8, height = 6, dpi = 300)

# plot 2: log-likelihood difference from unsteered baseline
unsteered_ll <- summary_data[summary_data$condition == "unsteered", ]
steered_data <- summary_data[summary_data$condition != "unsteered", ]

if (nrow(unsteered_ll) > 0 && nrow(steered_data) > 0) {
  # calculate differences (assuming same sequence order)
  steered_data$ll_diff <- NA
  for (i in 1:nrow(steered_data)) {
    seq_match <- unsteered_ll[unsteered_ll$seq_id == steered_data$seq_id[i], ]
    if (nrow(seq_match) > 0) {
      steered_data$ll_diff[i] <- steered_data$total_log_likelihood[i] - seq_match$total_log_likelihood[1]
    }
  }
  
  # calculate means and standard errors for differences
  diff_means <- steered_data %>%
    group_by(condition, scale) %>%
    summarise(mean_diff = mean(ll_diff, na.rm = TRUE),
              se_diff = sd(ll_diff, na.rm = TRUE) / sqrt(n()),
              .groups = 'drop')
  
  p2 <- ggplot(diff_means, aes(x = factor(scale), y = mean_diff, fill = condition)) +
    geom_bar(stat = "identity", position = "dodge", alpha = 0.8) +
    geom_errorbar(aes(ymin = mean_diff - se_diff, ymax = mean_diff + se_diff),
                  position = position_dodge(width = 0.9), width = 0.25) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "red", alpha = 0.7) +
    labs(title = "steering effect: log-likelihood change from baseline",
         x = "steering scale",
         y = "mean log-likelihood difference from unsteered",
         fill = "condition") +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
  
  ggsave(file.path(output_dir, "log_likelihood_difference.png"), p2, 
         width = 8, height = 6, dpi = 300)
}

# plot 3: sequence-specific effects
p3 <- ggplot(summary_data, aes(x = seq_id, y = total_log_likelihood, fill = condition)) +
  geom_bar(stat = "identity", position = "dodge", alpha = 0.8) +
  labs(title = "steering effects by sequence",
       x = "sequence ID",
       y = "total log-likelihood",
       fill = "condition") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave(file.path(output_dir, "sequence_specific_effects.png"), p3, 
       width = 10, height = 6, dpi = 300)

# create summary statistics table
summary_stats <- summary_data %>%
  group_by(condition, scale) %>%
  summarise(
    n_sequences = n(),
    mean_ll = mean(total_log_likelihood, na.rm = TRUE),
    sd_ll = sd(total_log_likelihood, na.rm = TRUE),
    min_ll = min(total_log_likelihood, na.rm = TRUE),
    max_ll = max(total_log_likelihood, na.rm = TRUE),
    .groups = 'drop'
  )

write_csv(summary_stats, file.path(output_dir, "steering_summary_stats.csv"))

cat("plots saved to:", output_dir, "\n")
cat("- log_likelihood_comparison.png\n")
cat("- log_likelihood_difference.png\n") 
cat("- sequence_specific_effects.png\n")
cat("- steering_summary_stats.csv\n")
cat("plotting complete.\n")