gsir <- function(params = list(beta = 2, gamma = 1),
                 N = 10000,
                 I0 = 0.01,
                 dt = 0.2,
                 tmax = 100,
                 maxit = 1e6) {
  I0_val <- min(1, round(N*I0))
  S <- N-I0_val
  I <- I0_val
  R <- 0
  dd <- data.frame(t = 0, S, I, R)
  t <- 0
  it <- 1
  next_t <- dt
  while (t < tmax && it < maxit && I > 0) {
    rates <- with(params, c(infection = beta*S*I/N, recovery = gamma*I))
    nrates <- length(rates)
    event <- sample(1:nrates, prob = rates/sum(rates), size = 1)
    if (event == 1) {
      S <- S-1
      I <- I+1
    } else if (event == 2) {
      I <- I-1
      R <- R+1
    }
    delta_t <- -log(runif(1))/sum(rates)
    t <- t + delta_t
    if (t > next_t) {
      dd <- rbind(dd, data.frame(t = next_t, S, I, R))
      next_t <- next_t + dt
    }
  }
  return(dd)
}
  

set.seed(101)
debug(gsir)
res <- gsir()

par(las=1)
matplot(res$t, res[,-1], log = "y", type = "l")
