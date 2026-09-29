# Compatibility entry point: monitor/discover only produce observations.
args <- commandArgs(trailingOnly=TRUE)
i <- match('--mode',args)
if(!is.na(i)) {
  if(i==length(args)) stop('Falta --mode')
  if(args[i+1]=='full') stop('Modo full retirado: ejecutar agent.R --role monitor/discover y después --role curate.')
  args[i] <- '--role'
}
env <- new.env(parent=.GlobalEnv)
env$commandArgs <- function(trailingOnly=FALSE) args
sys.source('scripts/agent.R',envir=env)
