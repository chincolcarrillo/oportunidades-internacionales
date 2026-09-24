if (dir.exists('.tools/R-library')) .libPaths(c(normalizePath('.tools/R-library'), .libPaths()))
options(encoding='UTF-8')
for (f in list.files('R', pattern='\\.R$', full.names=TRUE)) source(f, local=.GlobalEnv, encoding='UTF-8')
