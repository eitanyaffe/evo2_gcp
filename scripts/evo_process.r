library(reticulate)

np <- import("numpy")
logits <- np$load("jobs/evo-test-v18/output/input_seq1_logits.npy")
logits_r <- py_to_r(logits)
dim(logits_r) # Should show: 1 x L x V

embeddings <- np$load("jobs/evo-test-v18/output/input_seq1_embeddings_blocks_28_mlp_l3.npy")
embeddings_r <- py_to_r(embeddings)
dim(embeddings_r) # Should show: 1 x L x D
