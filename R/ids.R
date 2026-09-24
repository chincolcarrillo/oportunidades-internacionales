norm <- function(x) {
  x[is.na(x)] <- ''
  trimws(gsub('[^a-z0-9]+',' ',tolower(iconv(x, to='ASCII//TRANSLIT'))))
}
stable_id <- function(prefix, ...) paste0(prefix,'_',substr(digest::digest(paste(...,sep='\u001f'), algo='sha256',serialize=FALSE),1,20))
normalize_url <- function(url) {
  url <- trimws(url)
  p <- tryCatch(httr2::url_parse(url), error=function(e) NULL)
  if (is.null(p) || is.null(p$hostname)) return(url)
  p$hostname <- tolower(p$hostname); p$fragment <- NULL
  if (length(p$query)) p$query <- p$query[!grepl('^(utm_|fbclid$|gclid$)',names(p$query))]
  httr2::url_build(p)
}
split_urls <- function(x) {
  if (is.na(x) || !nzchar(x)) return(character())
  unique(vapply(strsplit(x,'\\s*\\|\\s*')[[1]],normalize_url,character(1)))
}
domain_of <- function(x) tolower(sub('^https?://([^/:]+).*','\\1',x))
clean_missing <- function(x) {
  x <- as.character(x)
  x[is.na(x) | trimws(x) %in% c('', 'No encontrado', 'No aplica')] <- NA_character_
  x
}
normalize_date <- function(x) {
  if (length(x)!=1 || is.na(x) || !grepl('^\\d{4}-\\d{2}-\\d{2}$',x)) return(NA_character_)
  d <- suppressWarnings(as.Date(x,format='%Y-%m-%d'))
  if (is.na(d) || format(d,'%Y-%m-%d') != x) NA_character_ else x
}
normalize_amount <- function(x) {
  # Only unambiguous numeric strings; ranges/monthly/conditional amounts remain text.
  if (is.na(x) || !grepl('^[0-9]+(\\.[0-9]{1,2})?$',x)) return(NA_real_)
  as.numeric(x)
}
normalize_frequency <- function(x) {
  z <- norm(x)
  map <- c(anual='anual',permanente='permanente',puntual='puntual',irregular='irregular','dos veces al ano'='dos_veces_al_ano','cada dos anos'='cada_dos_anos')
  if (!nzchar(z) || z=='no encontrado') return('no_encontrado')
  if (z %in% names(map)) unname(map[z]) else 'no_claro'
}
derive_state <- function(open, close, date=today(), rolling=FALSE, inactive=FALSE) {
  a <- normalize_date(open); b <- normalize_date(close)
  if (!is.na(b) && as.Date(b)<date) return('closed')
  if (!is.na(a) && as.Date(a)>date) return('upcoming')
  if (!is.na(a) && !is.na(b) && as.Date(a)<=date && as.Date(b)>=date) return('open')
  if (inactive) return('inactive')
  if (rolling) return('rolling')
  'unknown'
}
