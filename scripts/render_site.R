source('scripts/load.R')
quarto <- Sys.getenv('QUARTO_PATH',Sys.which('quarto'))
if(!nzchar(quarto) && .Platform$OS.type=='windows') {
  bundled <- 'C:/Program Files/RStudio/resources/app/bin/quarto/bin/quarto.cmd'
  if(file.exists(bundled)) quarto <- bundled
}
if(!nzchar(quarto)) stop('Quarto no encontrado: instalar Quarto o definir QUARTO_PATH.')
Sys.setenv(QUARTO_R=R.home('bin'),R_LIBS=paste(.libPaths(),collapse=.Platform$path.sep))
status <- system2(quarto,c('render','site'))
if(status!=0) stop('Quarto render falló.')
expected <- file.path('site/_site',paste0(c('index','fondos','estancias','proximos-cierres','cambios','metodologia'),'.html'))
stopifnot(all(file.exists(expected)))
