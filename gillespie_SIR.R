## Doob-Gillespie algorithm implementation for SIR model 
## https://en.wikipedia.org/wiki/Gillespie_algorithm
## https://cran.r-project.org/web/packages/GillespieSSA/index.html
## Gillespie SIR (Kermack-McKendrick) vignette:
##     https://cran.r-project.org/web/packages/GillespieSSA/vignettes/sir.html

## odin would be much faster, but doesn't do Gillespie -- only
##   http://epirecip.es/epicookbook/chapters/sir-stochastic-discretestate-discretetime/r_odin

library(GillespieSSA)

gsir <- function(parms = list(beta = 2, gamma = 1),
                 N = 10000,
                 I0 = 0.01,
                 dt = 0.2,
                 tmax = 100,
                 maxit = 1e6) {
  I0_val <- max(1, round(N*I0))
  S <- N-I0_val
  I <- I0_val
  R <- 0
  dd <- data.frame(t = 0, S, I, R)
  t <- 0
  it <- 1
  next_t <- dt
  while (t < tmax && it < maxit && I > 0) {
    rates <- with(parms, c(infection = beta*S*I/N, recovery = gamma*I))
    ## choose next event
    r0 <- runif(1)
    psum <- cumsum(rates)/sum(rates)
    for (event in seq_along(psum)) {
      if (r0 < psum[event]) break
    }
    ## execute event
    if (event == 1) {
      S <- S-1
      I <- I+1
    } else if (event == 2) {
      I <- I-1
      R <- R+1
    }
    ## choose elapsed time
    delta_t <- -log(runif(1))/sum(rates)
    t <- t + delta_t
    if (t > next_t) {
      ## report
      dd <- rbind(dd, data.frame(t = next_t, S, I, R))
      next_t <- next_t + dt
    }
  }
  return(dd)
}
  
set.seed(101)
res <- gsir()

par(las=1)
matplot(res$t, res[,-1], log = "y", type = "l")

## wrap GillespieSSA
gSSA_sir <- function(parms = list(beta = 2, gamma = 1, N=10000),
                     I0 = 0.01,
                     dt = 0.2,
                     tmax = 100,
                     maxit = 1e6,
                     ## Gillespie method
                     method = ssa.d()) {
  I0_val <- max(1, round(parms[["N"]]*I0))
  x0 <- c(S=parms[["N"]]-I0_val, I = I0_val, R = 0)
  ## specify transition events (column = transition, row = state variable)
  nu <- matrix(c(-1,0,1,-1,0,1), nrow=3, byrow=TRUE)
  ## rates (must use eval() internally?)
  a  <- c("beta*S*I/N", "gamma*I")
  out <- ssa(
    x0 = x0,
    a = a,
    nu = nu,
    parms = parms,
    tf = tmax,
    censusInterval = dt,
    method = method,
    simName = "gillespieSSA_SIR",
    verbose = FALSE)
  out
} 

set.seed(101)
res2 <- gSSA_sir()
matplot(res2$data[,1], res2$data[,-1],  log = "y", type = "l")
