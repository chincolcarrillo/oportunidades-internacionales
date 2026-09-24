monitor <- function(db,limit=Inf,fetcher=fetch_source,extractor=extract_source,run_id=stable_id('run',now()),force=FALSE) {
  checked <- changed <- errors <- 0L
  cfg <- read_config('sources'); cache <- new.env(parent=emptyenv())
  for(i in head(seq_len(nrow(db$sources)),limit)) {
    src <- db$sources[i,,drop=FALSE]
    if(!force && !is.na(src$last_checked) && difftime(Sys.time(),as.POSIXct(src$last_checked,format='%Y-%m-%dT%H:%M:%SZ',tz='UTC'),units='days') < (cfg$min_check_days %||% 3)) next
    checked <- checked+1L
    response <- if(exists(src$url,envir=cache,inherits=FALSE)) get(src$url,envir=cache) else { z <- fetcher(src$url); assign(src$url,z,envir=cache); z }
    db$sources$last_checked[i] <- now(); db$sources$http_status[i] <- as.character(response$status)
    if(response$status!=200 || !is.null(response$error)) {
      errors <- errors+1L
      db <- queue_review(db,src$opportunity_id,src$call_id,src$source_id,'source_unavailable',paste(response$error %||% 'HTTP',response$status,'; verificar página oficial alternativa'))
      next
    }
    hash <- response$hash %||% digest::digest(response$text,algo='sha256',serialize=FALSE)
    db$sources$content_hash[i] <- hash
    if(!identical(hash,src$content_hash)) { changed <- changed+1L; db$sources$last_changed[i] <- now() }
    if(identical(hash,src$extracted_hash)) next
    db$sources$is_official[i] <- as.character(official_url(src$url))
    db$sources$source_priority[i] <- if(official_url(src$url)) '3' else '6'
    result <- tryCatch(extractor(response$text,src$url),error=function(e) NULL)
    if(is.null(result)) {
      errors <- errors+1L
      db <- queue_review(db,src$opportunity_id,src$call_id,src$source_id,'extraction_failed','Extracción falló o API no configurada. Hash no marcado como extraído; se reintentará.')
      next
    }
    oi <- match(src$opportunity_id,db$opportunities$opportunity_id)
    ci <- match(src$call_id,db$calls$call_id)
    match_name <- !is.null(result$convocatoria) && norm(result$convocatoria)==norm(db$opportunities$convocatoria[oi])
    if(!match_name) {
      db <- queue_review(db,src$opportunity_id,src$call_id,src$source_id,'source_identity_mismatch','La extracción no corresponde inequívocamente al instrumento registrado; revisar nombre y fuente.')
    } else if(!is.na(ci) && !is.null(result$edicion) && !is.na(db$calls$edicion[ci]) && !grepl('^legacy_',db$calls$edicion[ci]) && result$edicion!=db$calls$edicion[ci]) {
      db <- consider_candidate(db,result,src$url,response$text,run_id)
    } else {
      db <- reconcile(db,src$source_id,result,response$text,run_id)
    }
    db$sources$extracted_hash[i] <- hash
  }
  list(db=db,checked=checked,changed=changed,errors=errors)
}
