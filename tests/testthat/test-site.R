withr::local_dir('../..')
testthat::test_that('sitio Quarto renderiza las seis páginas', {
  testthat::skip_if(Sys.getenv('RUN_RENDER_TEST')!='true','Activar RUN_RENDER_TEST=true para el render de integración.')
  testthat::expect_error(source('scripts/render_site.R',encoding='UTF-8'),NA)
  for(n in c('index','fondos','estancias','proximos-cierres','cambios','metodologia')) {
    path <- file.path('site/_site',paste0(n,'.html'))
    testthat::expect_true(file.exists(path))
    testthat::expect_true(file.info(path)$size>1000)
  }
})
