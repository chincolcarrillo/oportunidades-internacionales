withr::local_dir('../..')
fixture_db <- function() {
  db <- new_db(); url <- fixture_search(''); x <- fixture_extract('',url)
  db <- consider_candidate(db,x,url,fixture_fetch(url)$text)
  db$changes <- empty_table('changes'); db
}
testthat::test_that('legacy se lee sin modificar original y mapea campos', {
  path <- 'input/base_grants_investigacion_Chile.xlsm'; before <- digest::digest(file=path,algo='sha256')
  result <- migrate_legacy(path)
  testthat::expect_equal(nrow(result$raw),92)
  testthat::expect_equal(ncol(result$raw),22)
  testthat::expect_equal(result$db$opportunities$convocatoria[1],result$raw$instrumento[1])
  testthat::expect_equal(result$db$opportunities$region[1],result$raw$Origen_financiamiento[1])
  testthat::expect_true(all(is.na(result$db$opportunities$pais)))
  testthat::expect_equal(before,digest::digest(file=path,algo='sha256'))
})
testthat::test_that('URLs, IDs, fechas, montos y frecuencias son conservadores', {
  testthat::expect_equal(length(split_urls('https://a.org/a | https://b.org/b')),2)
  testthat::expect_equal(normalize_url('https://a.org/a?utm_source=x&edition=2026#top'),'https://a.org/a?edition=2026')
  testthat::expect_identical(stable_id('opp','a','b'),stable_id('opp','a','b'))
  testthat::expect_false(stable_id('opp','a','bc')==stable_id('opp','ab','c'))
  testthat::expect_equal(normalize_date('2026-12-15'),'2026-12-15')
  testthat::expect_true(is.na(normalize_date('2026-02-30')))
  testthat::expect_true(is.na(normalize_date('Mayo 2026')))
  testthat::expect_equal(normalize_amount('30000.50'),30000.5)
  testthat::expect_true(is.na(normalize_amount('hasta EUR 30.000 / mes')))
  testthat::expect_equal(normalize_frequency('Bianual'),'no_claro')
  testthat::expect_equal(normalize_frequency('dos veces al año'),'dos_veces_al_ano')
})
testthat::test_that('deduplicación usa capas sin fusionar similitudes', {
  db <- fixture_db()
  h <- duplicate_matches(db,'Research Futures','Spencer Foundation',fixture_search(''))
  testthat::expect_true(all(c('url','institution_name','domain_name') %in% h$reason))
  h <- duplicate_matches(db,'Research Future','Other')
  testthat::expect_true('fuzzy_review_only' %in% h$reason)
})
testthat::test_that('clasificación y estados por fecha', {
  testthat::expect_equal(classify_legacy('Research Grants'),'fondo')
  testthat::expect_equal(classify_legacy('Visiting researcher'),'estancia')
  testthat::expect_equal(classify_legacy('Visiting researcher','Financia proyectos de investigación'),'ambos')
  testthat::expect_equal(classify_legacy('Publication Subsidy Scheme'),'revisar')
  date <- as.Date('2026-09-24')
  testthat::expect_equal(derive_state('2026-09-01','2026-09-24',date),'open')
  testthat::expect_equal(derive_state('2026-09-01','2026-09-23',date),'closed')
  testthat::expect_equal(derive_state('2026-10-01',NA_character_,date),'upcoming')
  testthat::expect_equal(derive_state(NA_character_,NA_character_,date),'unknown')
})
testthat::test_that('cambio de cierre genera exactamente un cambio e idempotencia', {
  db <- fixture_db(); db$calls$fecha_cierre <- '2026-12-01'
  x <- fixture_extract('',fixture_search('')); x$fields <- Filter(function(f) f$field=='fecha_cierre',x$fields)
  first <- reconcile(db,db$sources$source_id,x,fixture_fetch('')$text,'test')
  testthat::expect_equal(nrow(first$changes),1)
  testthat::expect_equal(first$calls$fecha_cierre,'2026-12-15')
  second <- reconcile(first,db$sources$source_id,x,fixture_fetch('')$text,'test2')
  testthat::expect_equal(nrow(second$changes),1)
})
testthat::test_that('sin cambios no hay cambios ni extracción duplicada', {
  db <- fixture_db(); calls <- 0
  extractor <- function(text,url) {calls <<- calls+1; fixture_extract(text,url)}
  a <- monitor(db,fetcher=fixture_fetch,extractor=extractor,force=TRUE)
  b <- monitor(a$db,fetcher=fixture_fetch,extractor=extractor,force=TRUE)
  testthat::expect_equal(nrow(b$db$changes),0)
  testthat::expect_equal(calls,1)
})
testthat::test_that('404 conserva registros y no repite la revisión', {
  db <- fixture_db(); bad <- function(url) list(status=404,text='',error='HTTP 404')
  a <- monitor(db,fetcher=bad,force=TRUE)
  b <- monitor(a$db,fetcher=bad,force=TRUE)
  testthat::expect_identical(b$db$opportunities,db$opportunities)
  testthat::expect_identical(b$db$calls,db$calls)
  testthat::expect_equal(nrow(b$db$review_queue),1)
})
testthat::test_that('override prevalece y contradicción genera revisión', {
  db <- fixture_db(); db$calls$fecha_cierre <- '2026-12-01'
  overrides <- list(list(table='calls',id=db$calls$call_id,field='fecha_cierre',value='2026-12-01',reason='Confirmación humana'))
  x <- fixture_extract('',fixture_search(''))
  a <- reconcile(db,db$sources$source_id,x,fixture_fetch('')$text,'test',overrides)
  testthat::expect_equal(a$calls$fecha_cierre,'2026-12-01')
  testthat::expect_true('manual_override_conflict' %in% a$review_queue$reason)
})
testthat::test_that('inelegibles van a exclusiones y ambiguos a revisión', {
  x <- fixture_extract('',fixture_search('')); x$eligibility <- 'no'
  for(i in seq_along(x$fields)) if(x$fields[[i]]$field=='elegibilidad_uchile') {x$fields[[i]]$value <- 'No'; x$fields[[i]]$quote <- 'Universities in Chile are not eligible.'}
  no_text <- 'Universities in Chile are not eligible.'
  db <- consider_candidate(new_db(),x,fixture_search(''),no_text)
  testthat::expect_equal(nrow(db$excluded_candidates),1)
  testthat::expect_equal(nrow(db$opportunities),0)
  testthat::expect_equal(nrow(consider_candidate(db,x,fixture_search(''),fixture_fetch('')$text)$excluded_candidates),1)
  x$eligibility <- 'unknown'
  a <- consider_candidate(new_db(),x,fixture_search(''),fixture_fetch('')$text)
  testthat::expect_equal(nrow(a$review_queue),1)
  testthat::expect_equal(nrow(a$opportunities),0)
})
testthat::test_that('descubrimiento mock idempotente y ediciones separadas', {
  a <- discover(new_db(),1,fixture_search,fixture_fetch,fixture_extract)
  b <- discover(a$db,1,fixture_search,fixture_fetch,fixture_extract)
  testthat::expect_equal(nrow(b$db$opportunities),1)
  testthat::expect_equal(nrow(b$db$calls),1)
  x <- fixture_extract('',fixture_search('')); x$edicion <- '2027'
  c <- consider_candidate(b$db,x,fixture_search(''),sub('Edition 2026','Edition 2027',fixture_fetch('')$text))
  testthat::expect_equal(nrow(c$opportunities),1)
  testthat::expect_equal(nrow(c$calls),2)
})
testthat::test_that('fuente secundaria o cita inexistente no verifica cierre', {
  db <- fixture_db(); db$calls$fecha_cierre <- '2026-12-01'; db$sources$is_official <- 'FALSE'
  a <- reconcile(db,db$sources$source_id,fixture_extract('',fixture_search('')),fixture_fetch('')$text,'test')
  testthat::expect_equal(a$calls$fecha_cierre,'2026-12-01')
  db$sources$is_official <- 'TRUE'
  a <- reconcile(db,db$sources$source_id,fixture_extract('',fixture_search('')),'Texto sin respaldo','test')
  testthat::expect_equal(a$calls$fecha_cierre,'2026-12-01')
})
testthat::test_that('extracción fallida se reintenta aunque hash HTTP no cambie', {
  db <- fixture_db()
  a <- monitor(db,fetcher=fixture_fetch,extractor=function(...) stop('fixture error'),force=TRUE)
  testthat::expect_true(is.na(a$db$sources$extracted_hash))
  b <- monitor(a$db,fetcher=fixture_fetch,extractor=fixture_extract,force=TRUE)
  testthat::expect_false(is.na(b$db$sources$extracted_hash))
})
testthat::test_that('QA, schema y exportaciones mínimas', {
  db <- fixture_db()
  testthat::expect_silent(validate_db(db))
  p <- published_tables(db)
  testthat::expect_true(all(minimum_funds %in% names(p$fondos_investigacion)))
  testthat::expect_true(all(minimum_stays %in% names(p$estancias_investigacion)))
  testthat::expect_true(jsonvalidate::json_validate('data/fixtures/extraction.json','config/schemas/opportunity.schema.json',engine='ajv'))
  db$calls$fecha_cierre <- '2025-01-01'
  testthat::expect_error(validate_db(db),'Cierre anterior')
})
testthat::test_that('persistencia validada y roundtrip CSV sin pérdida', {
  db <- fixture_db(); path <- tempfile('db'); on.exit(unlink(path,recursive=TRUE))
  save_db(db,path); testthat::expect_equal(load_db(file.path(path,'canonical')),db)
  invalid <- db; invalid$calls$opportunity_id <- 'missing'
  testthat::expect_error(save_db(invalid,path),'Claves')
  testthat::expect_equal(load_db(file.path(path,'canonical')),db)
})
testthat::test_that('dos fuentes oficiales discrepantes requieren revisión', {
  db <- fixture_db(); db$calls$fecha_cierre <- '2026-12-01'
  x <- fixture_extract('',fixture_search('')); x$fields <- Filter(function(f) f$field=='fecha_cierre',x$fields)
  a <- reconcile(db,db$sources$source_id,x,fixture_fetch('')$text,'first')
  second <- a$sources[1,,drop=FALSE]; second$source_id <- 'src_second'; second$url <- 'https://www.spencer.org/second'
  a$sources <- rbind(a$sources,second)
  x$fields[[1]]$value <- '2026-12-20'; x$fields[[1]]$quote <- 'close on 20 December 2026'; x$fields[[1]]$url <- second$url
  b <- reconcile(a,second$source_id,x,'Applications close on 20 December 2026','second')
  testthat::expect_equal(b$calls$fecha_cierre,'2026-12-15')
  testthat::expect_true('sources_disagree' %in% b$review_queue$reason)
})
testthat::test_that('identidad diferente en página compartida no sobrescribe instrumento', {
  db <- fixture_db()
  wrong <- function(text,url) { x <- fixture_extract(text,url); x$convocatoria <- 'Other Program'; x }
  a <- monitor(db,fetcher=fixture_fetch,extractor=wrong,force=TRUE)
  testthat::expect_identical(a$db$opportunities,db$opportunities)
  testthat::expect_true('source_identity_mismatch' %in% a$db$review_queue$reason)
})
testthat::test_that('exclusión sin evidencia no se aplica automáticamente', {
  x <- fixture_extract('',fixture_search('')); x$eligibility <- 'no'
  a <- consider_candidate(new_db(),x,fixture_search(''),fixture_fetch('')$text)
  testthat::expect_equal(nrow(a$excluded_candidates),0)
  testthat::expect_equal(nrow(a$review_queue),1)
})
testthat::test_that('lectura bloqueada durante transacción incompleta', {
  root <- tempfile('recovery'); dir.create(root); dir.create(file.path(root,'.previous'))
  on.exit(unlink(root,recursive=TRUE))
  testthat::expect_error(load_db(file.path(root,'canonical')),'recuperación')
})
