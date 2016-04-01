cat("Loading ngtv.csv, pstv.csv, ntrl.csv ......")
ngtv <- read.csv(file="ngtv.csv", sep=",")
pstv <- read.csv(file="pstv.csv", sep=",")
ntrl <- read.csv(file="ntrl.csv", sep=",")
cat("Done\n")

cat("\nTesting 'score'\n")
cat("ngtv - ntrl\n")
res <- wilcox.test(ngtv[,1], ntrl[,1], paired=FALSE)
print(res)
ngnt <- res$p.value

cat("ntrl - pstv\n")
res <- wilcox.test(ntrl[,1], pstv[,1], paired=FALSE)
print(res)
ntps <- res$p.value

cat("ngtv - pstv\n")
res <- wilcox.test(ngtv[,1], pstv[,1], paired=FALSE)
print(res)
ngps <- res$p.value


cat("\n\nTesting 'fcount'\n")
cat("ngtv - ntrl\n")
res <- wilcox.test(ngtv[,2], ntrl[,2], paired=FALSE)
print(res)
ngnt <- res$p.value

cat("ntrl - pstv\n")
res <- wilcox.test(ntrl[,2], pstv[,2], paired=FALSE)
print(res)
ntps <- res$p.value

cat("ngtv - pstv\n")
res <- wilcox.test(ngtv[,2], pstv[,2], paired=FALSE)
print(res)
ngps <- res$p.value


cat("\n\nTesting 'vcount'\n")
cat("ngtv - ntrl\n")
res <- wilcox.test(ngtv[,3], ntrl[,3], paired=FALSE)
print(res)
ngnt <- res$p.value

cat("ntrl - pstv\n")
res <- wilcox.test(ntrl[,3], pstv[,3], paired=FALSE)
print(res)
ntps <- res$p.value

cat("ngtv - pstv\n")
res <- wilcox.test(ngtv[,3], pstv[,3], paired=FALSE)
print(res)
ngps <- res$p.value


cat("\n\nTesting 'responsetime'\n")
cat("ngtv - ntrl\n")
res <- wilcox.test(ngtv[,4], ntrl[,4], paired=FALSE)
print(res)
ngnt <- res$p.value

cat("ntrl - pstv\n")
res <- wilcox.test(ntrl[,4], pstv[,4], paired=FALSE)
print(res)
ntps <- res$p.value

cat("ngtv - pstv\n")
res <- wilcox.test(ngtv[,4], pstv[,4], paired=FALSE)
print(res)
ngps <- res$p.value

cat("\n\n-------\nngtv:\n")
print(mean(ngtv[,1]))
print(mean(ngtv[,2]))
print(mean(ngtv[,3]))
print(mean(ngtv[,4]))
cat("\n\n-------\nntrl:\n")
print(mean(ntrl[,1]))
print(mean(ntrl[,2]))
print(mean(ntrl[,3]))
print(mean(ntrl[,4]))
cat("\n\n-------\npstv:\n")
print(mean(pstv[,1]))
print(mean(pstv[,2]))
print(mean(pstv[,3]))
print(mean(pstv[,4]))