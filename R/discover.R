excluded_url <- function(db,url) {
  cfg <- read_config('exclusions')
  url %in% db$excluded_candidates$url || url %in% (unlist(cfg$urls) %||% character()) || domain_of(url) %in% (unlist(cfg$domains) %||% character())
}
consider_candidate <- function(db,x,url,text,run_id='discovery') {
  candidate_id <- stable_id('candidate',normalize_url(url))
  name <- x$convocatoria %||% NA_character_; institution <- x$institucion_financiante %||% NA_character_
  if(excluded_url(db,url)) return(db)
  exclusion_evidence <- any(vapply(x$fields %||% list(),function(f) identical(f$field,'elegibilidad_uchile') && identical(f$value,'No') && evidence_valid(f,text,url),logical(1)))
  scope_exclusion <- identical(x$scope,'out') && !is.null(x$reason) && nchar(x$reason)>=8 && grepl(x$reason,text,fixed=TRUE)
  if((identical(x$eligibility,'no') && exclusion_evidence || scope_exclusion) && official_url(url) && isTRUE(x$high_confidence)) {
    if(!candidate_id %in% db$excluded_candidates$candidate_id) db$excluded_candidates <- rbind(db$excluded_candidates,row('excluded_candidates',candidate_id=candidate_id,convocatoria=name,institucion_financiante=institution,url=url,reason=paste(x$eligibility,x$scope,x$reason),first_seen=now()))
    return(db)
  }
  hits <- duplicate_matches(db,name,institution,url)
  strong <- unique(hits$opportunity_id[hits$reason %in% c('institution_name','domain_name')])
  if(length(strong)==1 && !is.null(x$edicion)) {
    oid <- strong[1]; cid <- stable_id('call',oid,x$edicion)
    if(any(db$calls$opportunity_id==oid & db$calls$edicion==x$edicion)) return(db)
  } else {oid <- stable_id('opp',norm(name),norm(institution)); cid <- stable_id('call',oid,x$edicion %||% 'unknown')}
  required <- c('elegibilidad_uchile','tipo_oportunidad','convocatoria','institucion_financiante')
  evidenced <- vapply(x$fields %||% list(),function(f) evidence_valid(f,text,url),logical(1))
  names_evidenced <- vapply((x$fields %||% list())[evidenced],function(f) f$field,character(1))
  verified <- (x$fields %||% list())[evidenced]
  has_value <- function(field,value) any(vapply(verified,function(f) identical(f$field,field) && identical(f$value,value),logical(1)))
  clear <- official_url(url) && isTRUE(x$high_confidence) && identical(x$scope,'in') && identical(x$eligibility,'yes') &&
    !is.na(name) && !is.na(institution) && !is.null(x$edicion) && grepl(x$edicion,text,fixed=TRUE) && all(required %in% names_evidenced) &&
    has_value('elegibilidad_uchile','Sí') && has_value('convocatoria',name) && has_value('institucion_financiante',institution) && has_value('tipo_oportunidad',x$tipo_oportunidad)
  if(nrow(hits) && length(strong)!=1) clear <- FALSE
  if(!clear) return(queue_review(db,reason='candidate_review',details=jsonlite::toJSON(list(url=url,candidate=x,matches=hits),auto_unbox=TRUE,null='null')))
  kind <- x$tipo_oportunidad
  if(!kind %in% c('fondo','estancia','ambos')) return(queue_review(db,reason='candidate_scope',details=url))
  if(!oid %in% db$opportunities$opportunity_id) db$opportunities <- rbind(db$opportunities,row('opportunities',opportunity_id=oid,convocatoria=name,institucion_financiante=institution,tipo_oportunidad=kind,programa=name,frecuencia_normalizada='no_encontrado',first_seen=now(),last_seen=now(),active_record=TRUE))
  db$calls <- rbind(db$calls,row('calls',call_id=cid,opportunity_id=oid,edicion=x$edicion,elegibilidad_uchile='No claro (check)',estado_calculado='unknown',review_required=FALSE,first_seen=now()))
  sid <- stable_id('src',oid,cid,url)
  db$sources <- rbind(db$sources,row('sources',source_id=sid,opportunity_id=oid,call_id=cid,url=url,domain=domain_of(url),source_role='official_program',source_priority=3,is_official=TRUE))
  reconcile(db,sid,x,text,run_id)
}
discover <- function(db,limit=5,searcher=discover_search,fetcher=fetch_source,extractor=extract_source,run_id=stable_id('run',now())) {
  queries <- read_config('discovery_queries')$queries
  # Rotate the starting family weekly so a bounded budget does not starve later families.
  offset <- (as.integer(format(today(),'%V')) * 5L) %% length(queries)
  queries <- queries[((seq_along(queries)-1L+offset) %% length(queries))+1L]
  seen <- character(); count <- errors <- 0L
  for(q in queries) {
    if(count>=limit) break
    urls <- tryCatch(searcher(q$query),error=function(e) {errors <<- errors+1L; character()})
    for(url in head(setdiff(urls,seen),1L)) {
      if(count>=limit) break
      seen <- c(seen,url)
      if(excluded_url(db,url)) next
      # Existing program URLs still permit newly identified editions.
      count <- count+1L
      response <- fetcher(url)
      if(response$status!=200 || !is.null(response$error)) {errors <- errors+1L; db <- queue_review(db,reason='candidate_fetch_failed',details=url); next}
      x <- tryCatch(extractor(response$text,url),error=function(e) NULL)
      if(is.null(x)) {errors <- errors+1L; db <- queue_review(db,reason='candidate_extract_failed',details=url); next}
      dir.create('data/staging/evidence',recursive=TRUE,showWarnings=FALSE)
      jsonlite::write_json(list(url=url,extraction=x),file.path('data/staging/evidence',paste0(stable_id('candidate',url),'.json')),auto_unbox=TRUE,pretty=TRUE)
      db <- consider_candidate(db,x,url,response$text,run_id)
    }
  }
  list(db=db,candidates=count,errors=errors)
}
