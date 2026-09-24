official_url <- function(url) {
  cfg <- read_config('sources')
  domain_of(url) %in% (unlist(cfg$official_domains) %||% character())
}
fetch_source <- function(url) {
  cfg <- read_config('sources'); ua <- cfg$user_agent
  if(!grepl('^https?://',url)) stop('URL no HTTP')
  domain <- domain_of(url)
  if(domain %in% (unlist(cfg$blocked_domains) %||% character())) return(list(status=0,text='',error='Dominio bloqueado por configuración'))
  permitted <- tryCatch(robotstxt::paths_allowed(url,bots=ua),error=function(e) FALSE)
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
      doc <- xml2::read_html(body)
      xml2::xml_remove(rvest::html_elements(doc,'script,style,nav,footer,header,noscript'))
      main <- rvest::html_elements(doc,'main,article')
      body <- rvest::html_text2(if(length(main)) main else doc)
    }
    text <- trimws(gsub('\\s+',' ',paste(body,collapse=' ')))
    hash <- digest::digest(text,algo='sha256',serialize=FALSE)
    dir.create('data/staging/evidence',recursive=TRUE,showWarnings=FALSE)
    jsonlite::write_json(list(url=url,checked_at=now(),status=status,hash=hash,text=text),file.path('data/staging/evidence',paste0(hash,'.json')),auto_unbox=TRUE)
    list(status=status,text=text,hash=hash,error=NULL)
  },error=function(e) list(status=0,text='',error='Fallo HTTP/TLS/timeout; se conserva el dato anterior'))
}
