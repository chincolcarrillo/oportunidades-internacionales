official_url <- function(url) {
  cfg <- read_config('sources')
  domain_of(url) %in% (unlist(cfg$official_domains) %||% character())
}
robots_allowed <- function(url, ua, checker=robotstxt::paths_allowed) {
  tryCatch(isTRUE(checker(paths=url, bot=ua, user_agent=ua,
    ssl_verifypeer=1, use_futures=FALSE)), error=function(e) FALSE)
}
relevant_html_text <- function(body) {
  doc <- xml2::read_html(body)
  # Some sites wrap their entire main/article inside a header (including Leakey).
  # Header is not reliably navigation: deleting it can delete the opportunity.
  xml2::xml_remove(rvest::html_elements(doc,'script,style,nav,footer,noscript'))
  # Select outer content roots only; nested main/article must not duplicate text.
  main <- xml2::xml_find_all(doc,'//main[not(ancestor::main)] | //article[not(ancestor::main) and not(ancestor::article)]')
  text <- if(length(main)) paste(rvest::html_text2(main),collapse=' ') else ''
  if(nchar(trimws(text))<200) text <- rvest::html_text2(doc)
  trimws(gsub('\\s+',' ',paste(text,collapse=' ')))
}
fetch_source <- function(url) {
  cfg <- read_config('sources'); ua <- cfg$user_agent
  if(!grepl('^https?://',url)) stop('URL no HTTP')
  domain <- domain_of(url)
  if(domain %in% (unlist(cfg$blocked_domains) %||% character())) return(list(status=0,text='',error='Dominio bloqueado por configuración'))
  permitted <- robots_allowed(url,ua)
  if(!isTRUE(permitted)) return(list(status=0,text='',error='robots.txt no permite o no pudo verificarse'))
  Sys.sleep(cfg$request_delay_seconds %||% 2)
  tryCatch({
    req <- httr2::request(url) |> httr2::req_user_agent(ua) |> httr2::req_timeout(30) |>
      httr2::req_retry(max_tries=2) |> httr2::req_options(followlocation=FALSE) |> httr2::req_error(is_error=function(resp) FALSE)
    resp <- httr2::req_perform(req); status <- httr2::resp_status(resp)
    # Redirects are reviewed, so a new host is never fetched without its own robots check.
    if(status!=200) return(list(status=status,text='',error=paste('HTTP',status)))
    ct <- httr2::resp_header(resp,'content-type') %||% ''
    if(!grepl('html|text/plain',ct)) return(list(status=status,text='',error='Formato no HTML/texto; revisar PDF o fuente alternativa'))
    body <- httr2::resp_body_string(resp)
    if(nchar(body)>5000000) return(list(status=status,text='',error='Respuesta excede límite de tamaño'))
    if(grepl('html',ct)) {
      body <- relevant_html_text(body)
    }
    text <- trimws(gsub('\\s+',' ',paste(body,collapse=' ')))
    if(nchar(text)<200) return(list(status=status,text=text,error='Contenido insuficiente para extracción; revisar fuente alternativa'))
    hash <- digest::digest(text,algo='sha256',serialize=FALSE)
    dir.create('data/staging/evidence',recursive=TRUE,showWarnings=FALSE)
    jsonlite::write_json(list(url=url,checked_at=now(),status=status,hash=hash,text=text),file.path('data/staging/evidence',paste0(hash,'.json')),auto_unbox=TRUE)
    list(status=status,text=text,hash=hash,error=NULL)
  },error=function(e) list(status=0,text='',error='Fallo HTTP/TLS/timeout; se conserva el dato anterior'))
}
