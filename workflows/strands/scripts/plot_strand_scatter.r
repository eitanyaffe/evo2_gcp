plot_strand_scatter <- function(ifn_tab, ifn_codon, fdir, title) {
  df <- read.delim(ifn_tab)

  # determine if the codon is the original reference codon
  # specify colClasses since column aa can be T
  # which is automatically converted to TRUE
  ref <- read.delim(ifn_codon, colClasses = c(NULL, "character", NULL))
  ref_id <- paste(ref$coord, ref$aa, ref$codon, sep = "_")
  df$is_ref <- df$id == ref_id

  library(ggplot2)
  library(ggrepel)
  dir.create(fdir, showWarnings = FALSE, recursive = TRUE)

  # create labels by dropping string before first underscore
  df$label <- sub("^[^_]*_", "", df$id)


  # create scatter plot with codon labels
  p <- ggplot(df, aes(x = plus, y = minus)) +
    geom_point(aes(color = is_ref), size = 2) +
    scale_color_manual(values = c("FALSE" = "black", "TRUE" = "orange")) +
    geom_text_repel(aes(label = label),
      size = 3,
      box.padding = 0.5, point.padding = 0.2
    ) +
    theme_minimal() +
    labs(
      title = sprintf("position %s, reference: %s", title, ref_id),
      x = "Plus Strand Log-Likelihood",
      y = "Minus Strand Log-Likelihood"
    ) +
    theme(legend.position = "none")

  # save plot as PDF
  ofn <- file.path(fdir, sprintf("P_vs_M_strands_%s.pdf", title))
  ggsave(ofn, p, width = 8, height = 8)

  cat("plot saved to:", ofn, "\n")
}
