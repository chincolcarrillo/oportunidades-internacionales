withr::local_dir('../..')
agent_fixture <- function() {
  db <- consider_candidate(new_db(),fixture_extract('',fixture_search('')),fixture_search(''),fixture_fetch('')$text)
  db$changes <- empty_table('changes')
  db$calls$fecha_cierre <- '2026-12-01'
  db
}
testthat::test_that('productores no cambian base; cola tiene evidencia íntegra', {
  db <- agent_fixture(); initial <- db
  m <- observe_monitor(db,fetcher=fixture_fetch,run_id='test',force=TRUE)
  d <- observe_discover(db,1,fixture_search,fixture_fetch,'test')
  testthat::expect_identical(db,initial)
  testthat::expect_length(m,1); testthat::expect_length(d,1)
  root <- tempfile('queue'); on.exit(unlink(root,recursive=TRUE))
  write_proposal(m[[1]],root); write_proposal(d[[1]],root)
  testthat::expect_length(read_proposals(root),2)
  write_proposal(m[[1]],root)
  testthat::expect_length(read_proposals(root),2)
  altered <- m[[1]]; altered$text <- 'altered'
  testthat::expect_error(validate_proposal(altered),'alterada')
})
testthat::test_that('curador aplica, registra y no consume API dos veces', {
  db <- agent_fixture()
  p <- observe_monitor(db,fetcher=fixture_fetch,force=TRUE)
  calls <- 0L
  extract <- function(text,url) {calls <<- calls+1L; fixture_extract(text,url)}
  a <- curate_proposals(db,p,extract)
  testthat::expect_equal(a$calls$fecha_cierre,'2026-12-15')
  testthat::expect_equal(a$agent_decisions$status,'applied')
  b <- curate_proposals(a,p,extract)
  testthat::expect_identical(a,b); testthat::expect_equal(calls,1L)
  root <- tempfile('db'); on.exit(unlink(root,recursive=TRUE))
  save_db(b,root); testthat::expect_equal(load_db(file.path(root,'canonical')),b)
})
testthat::test_that('base posterior y evidencia vencida impiden sobrescritura', {
  db <- agent_fixture(); p <- observe_monitor(db,fetcher=fixture_fetch,force=TRUE)
  db$calls$fecha_cierre <- '2026-12-20'
  a <- curate_proposals(db,p,function(...) stop('No extraer'))
  testthat::expect_equal(a$agent_decisions$status,'stale')
  testthat::expect_identical(a$calls,db$calls)
  p[[1]]$observed_at <- '2020-01-01T00:00:00Z'
  b <- curate_proposals(db,p,fixture_extract)
  testthat::expect_equal(b$agent_decisions$status,'stale')
})
testthat::test_that('HTTP fallido conserva datos y registra revisión', {
  db <- agent_fixture()
  p <- observe_monitor(db,fetcher=function(url) list(status=404,text='',error='HTTP 404'),force=TRUE)
  a <- curate_proposals(db,p,function(...) stop('No extraer'))
  testthat::expect_identical(a$calls,db$calls)
  testthat::expect_identical(a$opportunities,db$opportunities)
  testthat::expect_equal(a$agent_decisions$status,'review')
  testthat::expect_true('source_unavailable' %in% a$review_queue$reason)
})
testthat::test_that('extracción fallida se reintenta y overrides prevalecen', {
  db <- agent_fixture(); p <- observe_monitor(db,fetcher=fixture_fetch,force=TRUE)
  a <- curate_proposals(db,p,function(...) stop('Falló'))
  testthat::expect_equal(a$agent_decisions$status,'retry')
  testthat::expect_true(is.na(a$sources$extracted_hash))
  b <- curate_proposals(a,p,fixture_extract)
  testthat::expect_equal(b$calls$fecha_cierre,'2026-12-15')
  testthat::expect_equal(b$agent_decisions$attempts,'2')
  original <- get_overrides
  withr::defer(assign('get_overrides',original,envir=.GlobalEnv))
  assign('get_overrides',function() list(list(table='calls',id=db$calls$call_id,
    field='fecha_cierre',value='2026-12-01',reason='Humana',quote='Applications close on 1 December 2026.')),envir=.GlobalEnv)
  c <- curate_proposals(db,p,fixture_extract)
  testthat::expect_equal(c$calls$fecha_cierre,'2026-12-01')
  testthat::expect_equal(c$agent_decisions$status,'review')
})
testthat::test_that('descubrimiento se incorpora únicamente en curaduría', {
  db <- new_db(); p <- observe_discover(db,1,fixture_search,fixture_fetch)
  testthat::expect_equal(nrow(db$calls),0)
  a <- curate_proposals(db,p,fixture_extract)
  testthat::expect_equal(nrow(a$calls),1)
  testthat::expect_equal(a$agent_decisions$status,'applied')
})
testthat::test_that('hash conocido evita extracción y límite omite fuentes recientes', {
  db <- agent_fixture(); p <- observe_monitor(db,fetcher=fixture_fetch,force=TRUE)
  db <- curate_proposals(db,p,fixture_extract)
  p <- observe_monitor(db,fetcher=fixture_fetch,force=TRUE,run_id='next')
  a <- curate_proposals(db,p,function(...) stop('No extraer'))
  testthat::expect_equal(tail(a$agent_decisions$status,1),'unchanged')
  s <- db$sources[1,,drop=FALSE]; s$source_id <- 'src_other'; s$last_checked <- NA_character_
  db$sources <- rbind(db$sources,s)
  b <- observe_monitor(db,limit=1,fetcher=fixture_fetch)
  testthat::expect_equal(b[[1]]$source_id,'src_other')
})
