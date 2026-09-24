source('scripts/load.R')
options(repos=c(CRAN='https://cloud.r-project.org'))
renv::snapshot(library=.libPaths(),lockfile='renv.lock',type='implicit',prompt=FALSE)
if(!file.exists('.Rprofile')) renv::activate()
