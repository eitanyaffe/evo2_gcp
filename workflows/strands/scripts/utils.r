library(reticulate)
library(seqinr)

np <- import("numpy")

softmax <- function(x) {
  exp_x <- exp(x - max(x))
  exp_x / sum(exp_x)
}

get_logits <- function(fn) {
  base.np <- np$load(fn)

  # convert numpy file to Rx
  mat <- py_to_r(base.np)[1, , ]

  # turn into probability matrix using softmax (N samples x M tokens)
  all <- t(apply(mat, 1, softmax))

  # focus only on nucleotides
  rr <- data.frame(
    A = all[, utf8ToInt("A") + 1],
    C = all[, utf8ToInt("C") + 1],
    G = all[, utf8ToInt("G") + 1],
    T = all[, utf8ToInt("T") + 1]
  )

  # NOTE: adding an empty first row since
  # output starts with second nucleotide
  empty <- data.frame(A = 0.25, C = 0.25, G = 0.25, T = 0.25)
  rr <- rbind(empty, rr)
  rr[-nrow(rr), ]
}

plot_values <- function(vals, ii, title, ylab, hh, odir) {
  panel <- c("red", "orange", "green")
  col.index <- (ii - 1) %% 3 + 1
  col <- panel[col.index]
  pch <- 19

  ofn <- sprintf("%s/%s.pdf", odir, title)
  cat(sprintf("Plotting to %s\n", ofn))
  pdf(ofn, width = 12, height = 5)
  plot(ii, vals[ii], xlab = "coord", ylab = ylab, col = col, pch = pch)

  points(hh, vals[hh])

  dev.off()
}
