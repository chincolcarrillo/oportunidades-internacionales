withr::local_dir('../..')
testthat::test_that('robots usa la interfaz real y mantiene validación TLS', {
  checker <- function(paths, bot, user_agent, ssl_verifypeer, use_futures) {
    testthat::expect_equal(paths,'https://example.org/grants')
    testthat::expect_equal(bot,'FACSOOpportunityMonitor/0.1')
    testthat::expect_identical(user_agent,bot)
    testthat::expect_identical(ssl_verifypeer,1)
    testthat::expect_false(use_futures)
    TRUE
  }
  testthat::expect_true(robots_allowed('https://example.org/grants','FACSOOpportunityMonitor/0.1',checker))
  testthat::expect_false(robots_allowed('https://example.org','bot',function(...) FALSE))
  testthat::expect_false(robots_allowed('https://example.org','bot',function(...) stop('unavailable')))
})
testthat::test_that('main vacío no oculta texto del cuerpo', {
  text <- paste(rep('Research grants fund educational projects.',10),collapse=' ')
  html <- paste0('<html><body><main></main><div>',text,'</div></body></html>')
  testthat::expect_match(relevant_html_text(html),'Research grants',fixed=TRUE)
})
testthat::test_that('valores no permitidos no entran al canónico', {
  testthat::expect_false(valid_field_value('frecuencia_normalizada','2'))
  testthat::expect_false(valid_field_value('elegibilidad_uchile','unknown'))
  testthat::expect_false(valid_field_value('requiere_cofinanciamiento','no'))
  testthat::expect_true(valid_field_value('frecuencia_normalizada','dos_veces_al_ano'))
})
testthat::test_that('excluir overhead no demuestra ausencia de cofinanciamiento', {
  url <- 'https://example.org/grants'
  item <- list(field='requiere_cofinanciamiento',value='No',quote='may not include indirect cost charges',url=url)
  testthat::expect_false(field_evidence_valid(item,item$quote,url))
  item$quote <- 'No matching funds are required.'
  testthat::expect_true(field_evidence_valid(item,item$quote,url))
})
testthat::test_that('header envolvente conserva main y no duplica article', {
  content <- paste('Research Grants. Application deadlines January 10 and July 15.',
    paste(rep('Applicants from any country with university affiliation may apply.',5),collapse=' '))
  html <- paste0('<html><body><a>Skip to content</a><header><nav>Menu</nav>',
    '<main><article><header>Research Grants</header><p>',content,
    '</p></article></main></header></body></html>')
  text <- relevant_html_text(html)
  testthat::expect_match(text,'January 10 and July 15',fixed=TRUE)
  testthat::expect_false(grepl('Menu',text,fixed=TRUE))
  testthat::expect_equal(length(gregexpr('Application deadlines',text,fixed=TRUE)[[1]]),1)
})
