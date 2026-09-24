fixture_fetch <- function(url) {
  x <- jsonlite::read_json('data/fixtures/source.json',simplifyVector=FALSE)
  list(status=x$status,text=x$text,hash=digest::digest(x$text,algo='sha256',serialize=FALSE),error=NULL)
}
fixture_extract <- function(text,url) {
  x <- jsonlite::read_json('data/fixtures/extraction.json',simplifyVector=FALSE)
  for(i in seq_along(x$fields)) x$fields[[i]]$url <- url
  x
}
fixture_search <- function(query) 'https://www.spencer.org/fixture-only-program'
