# Reproducible verification: fixtures only, no live website/API calls.
source('scripts/load.R')
files <- list.files('data/canonical',full.names=TRUE)
before <- vapply(files,digest::digest,character(1),file=TRUE,algo='sha256')
inputs <- jsonlite::read_json('docs/input_checksums.json',simplifyVector=TRUE)
for(n in names(inputs)) stopifnot(identical(inputs[[n]],digest::digest(file=file.path('input',n),algo='sha256')))

Sys.setenv(RUN_RENDER_TEST='true')
source('scripts/test.R',encoding='UTF-8')
source('scripts/demo_agents.R',encoding='UTF-8')
validate_db(load_db(),verbose=TRUE)

# Child processes use the same restored libraries, but no profile bootstrap.
Sys.setenv(R_LIBS=paste(.libPaths(),collapse=.Platform$path.sep))
for(role in c('monitor','discover','curate')) {
  status <- system2(file.path(R.home('bin'),'Rscript'),c('--vanilla','scripts/agent.R','--role',role,'--dry-run','--mock','--limit','3'))
  stopifnot(status==0)
}
status <- system2(file.path(R.home('bin'),'Rscript'),c('--vanilla','scripts/update.R','--mode','monitor','--dry-run','--mock','--limit','3'))
stopifnot(status==0)
after_files <- list.files('data/canonical',full.names=TRUE)
after <- vapply(after_files,digest::digest,character(1),file=TRUE,algo='sha256')
stopifnot(identical(before,after))
for(f in list.files('.github/workflows',full.names=TRUE)) stopifnot(is.list(yaml::read_yaml(f)))
writeLines(c('# Verificación de la arquitectura de tres agentes', '', paste('Ejecutada:',now()), '',
  '- Tests con fixtures, incluido render Quarto de seis páginas: completados sin fallas.',
  '- Demo completa: descubrimiento, cola, curaduría, vigilancia y actualización idempotente.',
  '- QA: cero errores. Permanecen las advertencias de duplicados y 92 convocatorias sin verificar.',
  '- CLI de los tres roles y compatibilidad update.R: mock/dry-run, exit 0.',
  '- SHA-256 canónicos: idénticos antes y después de la verificación.',
  '- SHA-256 de los originales XLSM/PDF: idénticos a la auditoría inicial.',
  '- YAML: parseado; tests de publicación exclusivamente manual y separación de permisos pasan.',
  '- No se hicieron llamadas API ni verificaciones web de oportunidades.',
  '- No se ejecutaron estos workflows en GitHub desde esta sesión; sus permisos y artefactos remotos requieren prueba allí.',
  '- No se hizo push, activación de Pages ni despliegue desde esta sesión.',
  '- No se afirma una inspección visual nueva: se comprobó render y existencia de las seis páginas.'),
  'docs/verification-agents.md',useBytes=TRUE)
cat('Verificación de tres agentes completa.\n')
