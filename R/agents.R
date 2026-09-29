# Observations are untrusted data. Only the curator returns a modified database.
record_fingerprint <- function(db, source_id) {
  s <- db$sources[match(source_id,db$sources$source_id),,drop=FALSE]
  if(!nrow(s) || is.na(s$source_id)) stop('Fuente desconocida')
  o <- db$opportunities[match(s$opportunity_id,db$opportunities$opportunity_id),,drop=FALSE]
  c <- db$calls[match(s$call_id,db$calls$call_id),,drop=FALSE]
  o <- o[,setdiff(names(o),c('first_seen','last_seen')),drop=FALSE]
  c <- c[,setdiff(names(c),c('first_seen','last_verified','review_required','estado_calculado')),drop=FALSE]
  digest::digest(jsonlite::toJSON(list(url=s$url,opportunity=o,call=c),na='null'),algo='sha256',serialize=FALSE)
}
safe_observe <- function(url,fetcher) {
  tryCatch(fetcher(url),error=function(e) list(status=0,text='',error='Error de lectura; conservar datos'))
}
make_proposal <- function(role,url,response,run_id,source_id=NA_character_,baseline=NA_character_) {
  text <- response$text %||% ''
  hash <- digest::digest(text,algo='sha256',serialize=FALSE)
  list(version=1L,proposal_id=stable_id('proposal',role,run_id,source_id,url,hash),
    role=role,run_id=run_id,observed_at=now(),url=url,source_id=source_id,
    baseline=baseline,http_status=as.integer(response$status),error=response$error %||% NA_character_,
    evidence_hash=hash,text=text)
}
validate_proposal <- function(p) {
  scalar <- function(x) is.character(x) && length(x)==1L && !is.na(x) && nzchar(x)
  required <- c('proposal_id','role','run_id','observed_at','url','evidence_hash')
  if(!all(vapply(p[required],scalar,logical(1))) || !identical(p$version,1L) ||
     !p$role %in% c('discover','monitor') || !grepl('^https?://[^ /]+',p$url) ||
     !is.character(p$text) || length(p$text)!=1L || is.na(p$text) ||
     length(p$http_status)!=1L || is.na(p$http_status)) stop('Propuesta inválida')
  if(p$role=='monitor' && (!scalar(p$source_id) || !scalar(p$baseline))) stop('Propuesta sin base de comparación')
  if(is.na(as.POSIXct(p$observed_at,format='%Y-%m-%dT%H:%M:%SZ',tz='UTC'))) stop('Fecha de observación inválida')
  if(!identical(p$evidence_hash,digest::digest(p$text,algo='sha256',serialize=FALSE))) stop('Evidencia alterada')
  expected <- stable_id('proposal',p$role,p$run_id,p$source_id %||% NA_character_,p$url,p$evidence_hash)
  if(!identical(expected,p$proposal_id)) stop('ID de propuesta inválido')
  invisible(TRUE)
}
write_proposal <- function(p,path='data/proposals') {
  validate_proposal(p)
  dir.create(path,recursive=TRUE,showWarnings=FALSE)
  dest <- file.path(path,paste0(p$proposal_id,'.json'))
  if(file.exists(dest)) return(invisible(dest))
  tmp <- tempfile('proposal-',tmpdir=path)
  on.exit(unlink(tmp),add=TRUE)
  jsonlite::write_json(p,tmp,auto_unbox=TRUE,na='null',pretty=TRUE)
  if(!file.rename(tmp,dest)) stop('No se pudo guardar propuesta')
  invisible(dest)
}
read_proposals <- function(path='data/proposals') {
  files <- sort(list.files(path,pattern='^proposal_.*\\.json$',full.names=TRUE))
  result <- lapply(files,function(f) {
    p <- jsonlite::read_json(f,simplifyVector=FALSE)
    validate_proposal(p)
    if(basename(f)!=paste0(p$proposal_id,'.json')) stop('Nombre de propuesta incompatible')
    p
  })
  if(length(result)) result <- result[order(vapply(result,function(p) p$observed_at,character(1)))]
  result
}
observe_monitor <- function(db,limit=200,fetcher=fetch_source,run_id=stable_id('run',now(),Sys.getpid()),force=FALSE) {
  cfg <- read_config('sources'); out <- list(); cache <- new.env(parent=emptyenv())
  for(i in seq_len(nrow(db$sources))) {
    if(length(out)>=limit) break
    s <- db$sources[i,,drop=FALSE]
    if(!force && !is.na(s$last_checked) && difftime(Sys.time(),as.POSIXct(s$last_checked,format='%Y-%m-%dT%H:%M:%SZ',tz='UTC'),units='days') < (cfg$min_check_days %||% 3)) next
    response <- if(exists(s$url,cache,inherits=FALSE)) get(s$url,cache) else {
      r <- safe_observe(s$url,fetcher); assign(s$url,r,cache); r
    }
    p <- make_proposal('monitor',s$url,response,run_id,s$source_id,record_fingerprint(db,s$source_id))
    p$previous_hash <- s$content_hash
    p$content_changed <- !identical(p$evidence_hash,s$content_hash)
    out[[length(out)+1L]] <- p
  }
  out
}
observe_discover <- function(db,limit=5,searcher=discover_search,fetcher=fetch_source,run_id=stable_id('run',now(),Sys.getpid())) {
  queries <- read_config('discovery_queries')$queries
  offset <- (as.integer(format(today(),'%V'))*5L) %% length(queries)
  queries <- queries[((seq_along(queries)-1L+offset) %% length(queries))+1L]
  out <- list(); seen <- character()
  for(q in queries) {
    if(length(out)>=limit) break
    urls <- tryCatch(searcher(q$query),error=function(e) NULL)
    if(is.null(urls)) {attr(out,'search_failed') <- TRUE; break}
    for(url in setdiff(urls,seen)) {
      if(length(out)>=limit) break
      seen <- c(seen,url)
      if(excluded_url(db,url)) next
      out[[length(out)+1L]] <- make_proposal('discover',url,safe_observe(url,fetcher),run_id)
    }
  }
  out
}
decide_proposal <- function(db,p,status,reason) {
  i <- match(p$proposal_id,db$agent_decisions$proposal_id)
  attempts <- if(is.na(i)) 1L else as.integer(db$agent_decisions$attempts[i])+1L
  value <- row('agent_decisions',proposal_id=p$proposal_id,role=p$role,run_id=p$run_id,
    decided_at=now(),status=status,reason=reason,attempts=attempts,evidence_hash=p$evidence_hash)
  if(is.na(i)) db$agent_decisions <- rbind(db$agent_decisions,value) else db$agent_decisions[i,] <- value
  db
}
curate_one <- function(db,p,extractor,max_age_days=14) {
  age <- as.numeric(difftime(Sys.time(),as.POSIXct(p$observed_at,format='%Y-%m-%dT%H:%M:%SZ',tz='UTC'),units='days'))
  if(age< -1 || age>max_age_days) return(list(db=db,status='stale',reason='Evidencia vencida; requiere nueva observación'))
  si <- if(p$role=='monitor') match(p$source_id,db$sources$source_id) else NA_integer_
  if(p$role=='monitor') {
    if(is.na(si) || !identical(db$sources$url[si],p$url)) return(list(db=db,status='stale',reason='Fuente eliminada o URL modificada'))
    if(!identical(record_fingerprint(db,p$source_id),p$baseline)) return(list(db=db,status='stale',reason='La base cambió desde la observación; volver a observar'))
    db$sources$last_checked[si] <- p$observed_at
    db$sources$http_status[si] <- as.character(p$http_status)
  }
  if(p$http_status!=200 || !is.null(p$error) && !is.na(p$error)) {
    db <- queue_review(db,source_id=if(p$role=='monitor') p$source_id else NA_character_,
      reason='source_unavailable',details=paste(p$url,p$error %||% 'HTTP',p$http_status))
    return(list(db=db,status='review',reason='Fuente no disponible; datos conservados'))
  }
  if(p$role=='monitor') {
    if(!identical(db$sources$content_hash[si],p$evidence_hash)) db$sources$last_changed[si] <- p$observed_at
    db$sources$content_hash[si] <- p$evidence_hash
    if(identical(db$sources$extracted_hash[si],p$evidence_hash)) return(list(db=db,status='unchanged',reason='Contenido ya extraído'))
  }
  if(!official_url(p$url)) {
    db <- queue_review(db,reason='unapproved_domain',details=p$url)
    return(list(db=db,status='review',reason='Dominio no aprobado; no se consume extracción'))
  }
  x <- tryCatch(extractor(p$text,p$url),error=function(e) NULL)
  if(is.null(x)) return(list(db=db,status='retry',reason='Extracción fallida o presupuesto agotado; reintentar'))
  before <- db
  if(p$role=='discover') {
    db <- consider_candidate(db,x,p$url,p$text,p$run_id)
  } else {
    s <- db$sources[si,,drop=FALSE]
    oi <- match(s$opportunity_id,db$opportunities$opportunity_id)
    ci <- match(s$call_id,db$calls$call_id)
    db$sources$is_official[si] <- 'TRUE'; db$sources$source_priority[si] <- '3'
    if(is.null(x$convocatoria) || norm(x$convocatoria)!=norm(db$opportunities$convocatoria[oi])) {
      db <- queue_review(db,s$opportunity_id,s$call_id,s$source_id,'source_identity_mismatch','Identidad incierta; conservar registro')
    } else if(!is.na(ci) && !is.null(x$edicion) && !is.na(db$calls$edicion[ci]) && !grepl('^legacy_',db$calls$edicion[ci]) && x$edicion!=db$calls$edicion[ci]) {
      db <- consider_candidate(db,x,p$url,p$text,p$run_id)
    } else db <- reconcile(db,p$source_id,x,p$text,p$run_id)
    db$sources$extracted_hash[si] <- p$evidence_hash
  }
  review <- nrow(db$review_queue)>nrow(before$review_queue) || any(db$changes$change_id %in% setdiff(db$changes$change_id,before$changes$change_id) & flag(db$changes$review_required))
  pending <- db$review_queue[db$review_queue$status=='pending',,drop=FALSE]
  review <- review || any(grepl(p$url,pending$details,fixed=TRUE)) ||
    (p$role=='monitor' && any(pending$source_id==p$source_id,na.rm=TRUE))
  applied <- !identical(db$opportunities,before$opportunities) || !identical(db$calls,before$calls)
  excluded <- nrow(db$excluded_candidates)>nrow(before$excluded_candidates)
  list(db=db,status=if(review) 'review' else if(excluded) 'excluded' else if(applied) 'applied' else 'unchanged',
    reason=if(review) 'Revisión pendiente; sólo campos seguros aplicados' else 'Procesada según evidencia y reglas vigentes')
}
curate_proposals <- function(db,proposals,extractor=extract_source,limit=200,max_age_days=14) {
  processed <- 0L
  for(p in proposals) {
    validate_proposal(p)
    old <- match(p$proposal_id,db$agent_decisions$proposal_id)
    if(!is.na(old) && db$agent_decisions$status[old]!='retry') next
    if(processed>=limit) break
    processed <- processed+1L
    result <- tryCatch({
      r <- curate_one(db,p,extractor,max_age_days)
      r$db <- apply_overrides(r$db,run_id=p$run_id)
      validate_db(r$db)
      r
    },error=function(e) list(db=db,status='review',reason='Propuesta rechazada por validación; base intacta'))
    db <- decide_proposal(result$db,p,result$status,result$reason)
  }
  db <- apply_overrides(db,run_id='curation-overrides')
  validate_db(db)
  db
}
