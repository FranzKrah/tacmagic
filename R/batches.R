##################################
## tacmagic - PET Analysis in R ##
## bathces.R                    ##
## (C) Eric E. Brown  2018      ##
## Beta version--check all work ##
##################################

# The exported batch functions.

#' Calculate one or more models for a batch of participants
#'
#' For a list of tac data (from load_batch) this calculates specified models
#' and saves in a tidy data.frame. Current model options are "SUVR", "Logan". 
#'
#' For further details about how the models are calculated, see the individual
#' functions that they rely on. "SUVR" uses suvr(), "Logan" uses
#' DVR_all_ref_Logan().
#'
#'@export
#'@param all_tacs A list by participant, of tac data (load_batch())
#'@param models A vector of names of the models to calculate
#'@param custom_model A function that can be run like other models (advanced)
#'@param ... The arguments that get passed to the specified models/custom model,
#' many are required; please check with model desired.
#'@return A table of SUVR values for the specified ROIs for all participants
#'@family Batch functions
#'@examples
#' participants <- c(system.file("extdata", "AD06.tac", package="tacmagic"),
#'                   system.file("extdata", "AD07.tac", package="tacmagic"),
#'                   system.file("extdata", "AD08.tac", package="tacmagic"))
#' 
#' tacs <- batch_load(participants, tac_file_suffix="")
#'
#' # Keeps only the ROIs without partial-volume correction (PMOD convention)
#' tacs <- lapply(tacs, split_pvc, FALSE)
#' 
#' batch <- batch_tm(tacs, models=c("SUVR", "Logan"), ref="Cerebellum_r",
#'                   SUVR_def=c(3000,3300,3600), k2prime=0.2, t_star=23)
#'
batch_tm <- function(all_tacs, models, custom_model=NULL, ...) {

  #----------------------------------------------------------------------------
  all_models <- names(model_definitions())
  if (!(all(models %in% all_models))) stop("Invalid model name(s) supplied.")
  
  master <- NULL
  
  # Run each model from available models --------------------------------------
  for (this_model in models) {
    MOD <- model_batch(all_tacs, model=this_model, ...)
    names(MOD) <- lapply(names(MOD), paste0, "_", this_model)  
    if (is.null(master)) master <- MOD else master <- data.frame(master, MOD)
  }
  
  # Run the custom model if one was specified ---------------------------------
  if(!is.null(custom_model)) {
    MOD <- model_batch(all_tacs, model=custom_model, ...)
    names(MOD) <- lapply(names(MOD), paste0, "_custom")
    if (is.null(master)) master <- MOD else master <- data.frame(master, MOD)
  }

  return(master)
}

#' Load (+/- merge) ROIs for batch of participants
#'
#' For a vector of participant IDs and correspondingly named tac files,
#' this loads the tac files. If roi_m = T, then can also merge ROIs into 
#' larger ROIs based on the optional parameters that follow.
#'
#' See load_tac() for specifics.
#'
#'@export
#'@param participants A vector of participant IDs
#'@param dir A directory and/or file name prefix for the tac/volume files
#'@param tac_format Format of tac files provided: See load_tac()
#'@param tac_file_suffix How participant IDs corresponds to the TAC files
#'@param roi_m TRUE if you want to merge atomic ROIs into larger ROIs (and if 
#' not, the following parameters are not used)
#'@param vol_format The file format that includes volumes: See load_vol()
#'@param vol_file_suffix How participant IDs correspond to volume files
#'@param ROI_def Object that defines combined ROIs, see ROI_definitions.R
#'@param PVC For PVC, true where the data is stored as _C in same tac file
#'@param merge Passes value to tac_roi(); T to also incl. original atomic ROIs
#'@return A list of data.frames, each is a participant's TACs
#'@family Batch functions
#'@examples
#' # For the working example, the participants are full filenames.
#' participants <- c(system.file("extdata", "AD06.tac", package="tacmagic"),
#'                   system.file("extdata", "AD07.tac", package="tacmagic"),
#'                   system.file("extdata", "AD08.tac", package="tacmagic"))
#' 
#' tacs <- batch_load(participants, tac_file_suffix="")
batch_load <- function(participants, dir="", tac_file_suffix=".tac",
                       tac_format="PMOD", roi_m=FALSE, PVC=NULL, 
                       vol_file_suffix=NULL, vol_format=NULL, 
                       merge=NULL, ROI_def=NULL) {
  
  if (!roi_m) {
    if (!all(c(is.null(vol_format), is.null(vol_file_suffix), is.null(ROI_def), 
              is.null(PVC)))) {
      warning("You specified parameters used for volume-based ROI merging, but 
               roi_m is FALSE so those parameters will not be used.")
    }
  }

  r <- lapply(participants, load_tacs, dir=dir, tac_format=tac_format, 
              roi_m=roi_m, tac_file_suffix=tac_file_suffix, 
              vol_file_suffix=vol_file_suffix, 
              vol_format=vol_format, ROI_def=ROI_def, PVC=PVC, merge=merge)
  
  names(r) <- participants

  return(r)
}

#' Obtain values from voistat files (using load_voistat() for a batch.
#'
#' For a vector of participant IDs and correspondingly named .voistat files,
#' this extracts the value from the files for the specified ROIs.
#' participants can also be a vector of filenames, in which case set dir="" and
#' filesuffix="", as in the example.
#'
#' See load_voistat() for specifics.
#'
#'@export
#'@param participants A vector of participant IDs
#'@param ROI_def Object that defines combined ROIs, see ROI_definitions.R
#'@param dir Directory and/or filename prefix of the files
#'@param filesuffix Optional filename characters between ID and ".voistat"
#'@param varname The name of the variable being extracted, e.g. "SRTM"
#'@return A table of values for the specified ROIs for all participants
#'@family Batch functions
#'@examples
#' participants <- c(system.file("extdata", "AD06_BPnd_BPnd_Logan.voistat", 
#'                               package="tacmagic"),
#'                    system.file("extdata", "AD07_BPnd_BPnd_Logan.voistat", 
#'                                package="tacmagic"),
#'                    system.file("extdata", "AD08_BPnd_BPnd_Logan.voistat", 
#'                                package="tacmagic"))
#' 
#' batchtest <- batch_voistat(participants=participants, ROI_def=roi_ham_pib(), 
#'                            dir="", filesuffix="", varname="Logan") 
#'
batch_voistat <- function(participants, ROI_def, dir="", filesuffix=".voistat", 
                          varname="VALUE") {

  voistat_file <- paste0(dir, participants[1], filesuffix)

  first <- load_voistat(voistat_file, ROI_def)
  master <- t(first)
  master <- master[-1,]

  for (each in participants) {
    voistat_file <- paste0(dir, each, filesuffix)
    VALUE <- load_voistat(voistat_file, ROI_def)
    trans <- t(VALUE)
    row.names(trans) <- each
    master <- rbind(master,trans)
  }

  master <- as.data.frame(master)
  names(master) <- lapply(names(master), paste0, "_", varname)
  return(master)
}
