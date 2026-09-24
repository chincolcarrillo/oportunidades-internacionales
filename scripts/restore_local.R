# Reuse downloaded packages to populate the isolated renv project library.
if(dir.exists('.tools/R-library')) .libPaths(c(normalizePath('.tools/R-library'),.libPaths()))
lock <- renv::lockfile_read('renv.lock')
renv::hydrate(packages=names(lock$Packages),library=renv::paths$library(),sources=c(normalizePath('.tools/R-library'),R.home('library')),prompt=FALSE)
