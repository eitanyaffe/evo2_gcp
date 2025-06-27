library(reticulate)

np <- import("numpy")

get_logits <- function(file) {
  logits <- np$load(file)
  logits_r <- py_to_r(logits)[1, , ]
  return(logits_r)
}

wt_logits <- get_logits("jobs/evo-combined-v7/output/input_Ecoli_gyrA_WT_logits.npy")
mut_logits <- get_logits("jobs/evo-combined-v7/output/input_Ecoli_gyrA_resistant_logits.npy")

diff_logits <- 10^wt_logits - 10^mut_logits
ed_logits <- sqrt(rowSums(diff_logits^2))
barplot(ed_logits, names.arg = seq_along(ed_logits), xlim = c(0, 600), las = 2)

get_embeddings <- function(file) {
  df <- np$load(file)
  df <- py_to_r(df)[1, , ]
  return(df)
}

s1 <- get_embeddings("jobs/evo-combined-v9/output/input_83_S1_embeddings_blocks_28_mlp_l3.npy")
s2 <- get_embeddings("jobs/evo-combined-v9/output/input_83_S2_embeddings_blocks_28_mlp_l3.npy")
l <- get_embeddings("jobs/evo-combined-v9/output/input_83_L_embeddings_blocks_28_mlp_l3.npy")
st <- get_embeddings("jobs/evo-combined-v9/output/input_83_Stop_embeddings_blocks_28_mlp_l3.npy")

plot_diff <- function(seq1, seq2, range = NULL) {
  diff <- seq1 - seq2
  ed_embeddings <- sqrt(rowSums(diff^2))
  print(which.max(ed_embeddings))
  cols <- ifelse(seq_along(ed_embeddings) %% 3 == 1, "#ffae00", "#00b3ff")
  if (!is.null(range)) {
    ix <- range
  } else {
    ix <- 1:length(ed_embeddings)
  }
  barplot(ed_embeddings[ix], names.arg = ix, las = 2, col = cols[ix], border = NA)
}

rr <- 230:260
plot_diff(s1, s2, rr)
plot_diff(s1, l, rr)
plot_diff(s1, st, rr)
plot_diff(s2, l, rr)
plot_diff(s2, st, rr)
plot_diff(l, st, rr)

ss <- get_embeddings("jobs/evo-combined-v8/output/input_WT_RC_1_embeddings_blocks_28_mlp_l3.npy")

plot_mat <- function(mat, range = NULL, pdf_filename = NULL) {
  if (!is.null(range)) {
    range <- seq_along(dim(mat)[1])
  }
  # Calculate pairwise Euclidean distances between rows
  dd <- as.matrix(dist(mat[range, ]))

  # Open PDF device
  if (!is.null(pdf_filename)) {
    pdf(file = pdf_filename, width = 8, height = 8)
  }
  # Create heatmap
  heatmap(dd,
    col = colorRampPalette(c("orange", "blue", "white"))(100), symm = TRUE,
    Rowv = NA, Colv = NA,
    labRow = range, labCol = range,
    main = "Heatmap of Euclidean Distances",
    xlab = "position", ylab = "position"
  )

  # Close PDF device
  if (!is.null(pdf_filename)) {
    dev.off()
  }
}

plot_mat(ss[2000:3000, ])

plot_mat(s1, range = 200:400)
