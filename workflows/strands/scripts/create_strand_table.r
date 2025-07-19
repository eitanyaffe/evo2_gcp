source("scripts/utils.r")

# ensure seqinr is loaded
library(seqinr)

get_total_ll <- function(pp, fasta) {
  nts <- colnames(pp)
  ii <- match(fasta, nts)
  if (length(ii) != nrow(pp)) stop("Length of 'fasta' must match number of rows in 'pp'")
  if (any(is.na(ii))) stop("Some nucleotides in 'fasta' not found in 'pp' column names")

  # sum log2 of probabilities, note these are negative values
  sum(log2(pp[cbind(1:nrow(pp), ii)]))
}

get_total_ll_all <- function(xids, idir, fasta) {
  rr <- NULL
  for (id in xids) {
    fn <- sprintf("%s/input_%s_logits.npy", idir, id)
    if (!file.exists(fn)) {
      fn <- gsub("_Z_", "___", fn)
    }
    pp <- get_logits(fn)
    fasta.id <- toupper(fasta[[id]])
    total_ll <- get_total_ll(pp, fasta.id)
    rr <- rbind(rr, data.frame(id = id, total_ll = total_ll))
  }
  rr
}

create_strand_table <- function(ifn, idir, ofn) {
  cat(sprintf("reading fasta file %s\n", ifn))
  fasta <- read.fasta(ifn)

  # get plus and minus ids
  ids <- names(fasta)
  ids <- unique(gsub("_[PM]$", "", ids))
  plus_ids <- sprintf("%s_P", ids)
  minus_ids <- sprintf("%s_M", ids)

  # read logit files
  cat(sprintf("reading logit files for %d ids from %s\n", length(ids), idir))
  rr.plus <- get_total_ll_all(xids = plus_ids, idir = idir, fasta = fasta)
  rr.minus <- get_total_ll_all(xids = minus_ids, idir = idir, fasta = fasta)

  # merge plus and minus logit of strands
  rr <- data.frame(id = ids, plus = rr.plus$total_ll, minus = rr.minus$total_ll)

  cat(sprintf("saving to %s\n", ofn))
  write.table(rr, ofn, sep = "\t", row.names = FALSE, quote = FALSE)
}
