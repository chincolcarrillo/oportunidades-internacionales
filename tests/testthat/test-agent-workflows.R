withr::local_dir('../..')
testthat::test_that('publicación sólo manual, restringida a propietaria y commit explícito', {
  w <- yaml::read_yaml('.github/workflows/publish-site.yml')
  events <- w[['on']] %||% w[['TRUE']]
  testthat::expect_named(events,'workflow_dispatch')
  testthat::expect_true(events$workflow_dispatch$inputs$commit_sha$required)
  authorization <- w$jobs$build$steps[[1]]
  testthat::expect_match(authorization$run,'test "$ACTOR" = "$OWNER"',fixed=TRUE)
  testthat::expect_match(authorization$run,'test "$TRIGGERING_ACTOR" = "$OWNER"',fixed=TRUE)
  testthat::expect_match(w$jobs$deploy[['if']],'github.triggering_actor',fixed=TRUE)
  testthat::expect_equal(w$jobs$deploy$permissions$pages,'write')
})
testthat::test_that('roles sin escritura y persistencia posterior a QA/render', {
  w <- yaml::read_yaml('.github/workflows/update-data.yml')
  testthat::expect_equal(w$permissions$contents,'read')
  for(n in c('discovery','monitoring','curation')) testthat::expect_null(w$jobs[[n]]$permissions)
  testthat::expect_equal(w$jobs$persist$permissions$contents,'write')
  testthat::expect_equal(w$jobs$persist$needs,'curation')
  steps <- w$jobs$curation$steps
  commands <- vapply(steps,function(s) s$run %||% '',character(1))
  testthat::expect_true(all(c('Rscript scripts/test.R','Rscript scripts/qa.R','Rscript scripts/render_site.R') %in% commands))
  persist <- paste(vapply(w$jobs$persist$steps,function(s) s$run %||% '',character(1)),collapse='\n')
  testthat::expect_match(persist,'git add data/canonical data/published data/proposals data/agent-evidence',fixed=TRUE)
  testthat::expect_false(grepl('--force',persist,fixed=TRUE))
  testthat::expect_false(grepl('OPENAI_API_KEY',paste(capture.output(str(w$jobs$persist)),collapse='')))
})
