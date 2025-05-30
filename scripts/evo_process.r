library(reticulate)

np <- import("numpy")
logits <- np$load("jobs/evo-test-v11/output/input_seq1_logits.npy")
logits_r <- py_to_r(logits)
dim(logits_r) # Should show: 1 x L x V
