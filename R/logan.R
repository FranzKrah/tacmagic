##################################
## PET Analysis in R            ##
## reference_Logan.R            ##
## (C) Eric E. Brown  2018      ##
## PEAR v devel                 ##
## Beta version--check all work ##
##################################

# See Logan 1996 in references().

#' Non-invasive reference Logan method
#'
#' This calculates the coefficient from the non-invasive Logan method, which
#' is equal to DVR. Works for a single tac (target).
#'
#'@export
#'@param tac_data The time-activity curve data from calcTAC()
#'@param target The name of the target ROI, e.g. "frontal"
#'@param ref The reference region, e.g. "cerebellum"
#'@param k2prime A fixed value for k2' must be specified (e.g. 0.2)
#'@param t_star If 0, t* will be calculated using find_t_star()
#'@param method Method of inntegration, "trapz" or "integrate"
#'@return Data frame with calculate DVRs for all ROIs
#'@examples
DVR_reference_Logan <- function(tac_data, target, ref, k2prime, t_star,
method="trapz") {
    model <- reference_Logan_lm(tac_data, target, ref, k2prime, t_star, method)
    DVR <- model$coefficients[[2]]
    return(DVR)
}


#' Non-invasive reference Logan method for all ROIs in tac data
#'
#' This calculates the DVR using the non-invasive reference Logan method for
#' all TACs in a supplied tac file. It uses DVR_reference_Logan.
#'
#'@export
#'@param tac_data The time-activity curve data from calcTAC()
#'@param reference The reference region, e.g. "cerebellum"
#'@param k2prime A fixed value for k2' must be specified (e.g. 0.2)
#'@param t_star If 0, t* will be calculated using find_t_star()
#'@param method Method of inntegration, "trapz" or "integrate"
#'@return Data frame with calculate DVRs for all ROIs
#'@examples
DVR_all_reference_Logan <- function(tac_data, reference, k2prime, t_star=0,
                                    method="trapz") {
    
    DVRtable <- new_table(tac_data, "DVR")
    
    ROIs <- names(tac_data)[3:length(names(tac_data))]
    for (ROI in ROIs) {
        message(paste("Trying", ROI))
        attempt <- try(DVR_reference_Logan(tac_data, target=ROI, ref=reference,
                                           k2prime=k2prime, t_star=t_star,
                                           method=method))
        if (class(attempt) == "try-error") {
            attempt <- NA
        }
        DVRtable[ROI, "DVR"] <- attempt
    }
    return(DVRtable)
}


#' Non-invasive reference Logan plot
#'
#' This plots the non-invasive Logan plot.
#'
#'@export
#'@param tac_data The time-activity curve data from calcTAC()
#'@param ref The reference region, e.g. "cerebellum"
#'@param k2prime A fixed value for k2' must be specified (e.g. 0.2)
#'@param t_star If 0, t* will be calculated using find_t_star()
#'@param method Method of inntegration, "trapz" or "integrate"
#'@return No return
#'@examples
plot_reference_Logan <- function(tac_data, target, ref, k2prime, t_star=0,
                                 method="trapz") {
    model <- reference_Logan_lm(tac_data, target, ref, k2prime, t_star, method)
    xy <- reference_Logan_xy(tac_data, target, ref, k2prime, method)
    x <- xy$x
    y <- xy$y
    if (t_star == 0) t_star <- find_t_star(x, y)
    
    par(mfrow=c(1,2))
    
    plotTAC2(tac_data, ROIs=c(target,ref))
    
    plot(y~x)
    abline(model)
    abline(v=x[t_star])
}



## Helper functions

# The non-invasive reference Logan method
#' @noRd
reference_Logan_xy <- function(tac, target, ref, k2prime, method) {
    
  mid_time <- (tac$start + tac$end) / 2
  
  # Derive functions for TACs by interpolation.
  target_tac <- approxfun(x=mid_time, y=tac[,target], method = "constant",
                          rule=2)
  ref_tac <- approxfun(x=mid_time, y=tac[,ref], method = "constant", rule=2)
  
  
  if (method == "trapz") {
    frames <- 1:length(mid_time)
    yA <- sapply(frames, FUN=vAUC, x=mid_time, y=tac[,target])
    xA <- sapply(frames, FUN=vAUC, x=mid_time, y=tac[,ref]) + (tac[,ref] /
                                                                    k2prime)
  } else if (method == "integrate") {
    yA <- sapply(mid_time, FUN=vintegrate, lower=mid_time[1], f=target_tac)
    xA <- sapply(mid_time, FUN=vintegrate, lower=mid_time[1], f=ref_tac) + (
                                                            tac[,ref] / k2prime)
  }

  yB <- tac[,target]
  y <- yA / yB
  xB <- yB
  x <- xA / xB

  output <- data.frame(x,y)

  return(output)
}


# The non-invasive reference Logan method -- linear model starting from t*
#' @noRd
reference_Logan_lm <- function(tac_data, target, ref, k2prime, t_star, method) {
    
  xy <- reference_Logan_xy(tac_data, target=target, ref=ref, k2prime=k2prime, 
                           method=method)
  
  x <- xy$x
  y <- xy$y
  
  if (t_star == 0) t_star <- find_t_star(x, y)
  message(paste("t* is", t_star))
  
  model <- lm(y[t_star:length(y)] ~ x[t_star:length(x)])
  return(model)
}


# The Logan graphical analysis method finds the slope after a point t*; this
# function calculates t* as the earliest time in which all residuals are less
# than the specified proportion (default 0.10 or 10%) of the actual value.
#' @noRd
find_t_star <- function(x, y, error=0.10) {
    
    frames <- length(y)
    
    for (i in 1:frames) {
        linear_model <- lm(y[i:frames]~x[i:frames])
        if (all((linear_model$residuals / y[i:frames]) < error )) {
            t_star <- i
            break
        }
    }
    if (t_star == 0) {
        stop("No suitable t* found.")
    }
    return(t_star)
}


# Helper function to use integrate() with sapply(), simply re-arranging the
# arguments of integrate() so that upper is the first argument, and returns
# just the integrate() value.
#' @noRd
vintegrate <- function(upper, lower, fn) {
    v <- integrate(fn, lower=lower, upper=upper, stop.on.error=F)
    return(v$value)
}


#' @noRd
vAUC <- function(frames,x,y) {
    AUC <- pracma::trapz(x[1:frames], y[1:frames])
    return(AUC)
}