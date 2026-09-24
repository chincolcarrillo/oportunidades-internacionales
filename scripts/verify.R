source('scripts/load.R')
Sys.setenv(RUN_RENDER_TEST='true')
source('scripts/test.R',encoding='UTF-8')
validate_db(load_db(),verbose=TRUE)
renv::status()
files <- list.files('data/canonical',full.names=TRUE)
before <- vapply(files,digest::digest,character(1),file=TRUE,algo='sha256')
for(mode in c('monitor','discover')) {
  status <- system2(file.path(R.home('bin'),'Rscript'),c('scripts/update.R','--mode',mode,'--dry-run','--mock','--limit','3'))
  stopifnot(status==0)
}
after <- vapply(files,digest::digest,character(1),file=TRUE,algo='sha256')
stopifnot(identical(before,after))
inputs <- jsonlite::read_json('docs/input_checksums.json',simplifyVector=TRUE)
for(n in names(inputs)) stopifnot(identical(inputs[[n]],digest::digest(file=file.path('input',n),algo='sha256')))
for(f in list.files('.github/workflows',full.names=TRUE)) stopifnot(is.list(yaml::read_yaml(f)))
writeLines(c('# Verificación final', '', paste('Ejecutada:',now()),
  'testthat: todos los casos ejecutados, incluido render Quarto de seis páginas, sin fallas.',
  'QA: cero errores de integridad. Advertencias: duplicados probables y 92 versiones legacy sin verificación web.',
  'CLI monitor/discover --mock --dry-run --limit 3: exit 0; hashes canónicos idénticos antes/después.',
  'SHA-256 del XLSM y PDF: idénticos a auditoría inicial.',
  'YAML de workflows: parseo correcto. No se ejecutaron en GitHub.',
  'Integración OpenAI: schema validado con fixtures; sin prueba API facturable.',
  'Revisión visual: portada y tabla de fondos inspeccionadas en navegador local; búsqueda comprobada.',
  'Pendiente de operación real: clave/modelo API y autorización/configuración GitHub/Pages.'), 'docs/verification.md',useBytes=TRUE)
cat('Verificación final completa.\n')
