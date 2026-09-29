critical_fields <- c('elegibilidad_uchile','fecha_apertura','fecha_cierre','monto_min','monto_max','monto_financiamiento_texto','moneda','requisitos_contraparte','requiere_cofinanciamiento','estado_calculado','estado_fuente')
editable_opportunity <- setdiff(schema$opportunities,c('opportunity_id','legacy_source_id','first_seen','last_seen','active_record'))
editable_call <- setdiff(schema$calls,c('call_id','opportunity_id','first_seen','last_verified','review_required','evidence_source_id','eligibility_evidence','closing_evidence','estado_calculado'))
valid_field_value <- function(field,value) {
  enums <- list(elegibilidad_uchile=c('Sí','No claro (check)','No'),tipo_oportunidad=c('fondo','estancia','ambos'),
    frecuencia_normalizada=c('anual','dos_veces_al_ano','cada_dos_anos','permanente','puntual','irregular','no_encontrado','no_claro'),
    requiere_cofinanciamiento=c('Sí','No','No claro (check)'))
  if(field %in% names(enums)) return(value %in% enums[[field]])
  if(field %in% c('fecha_apertura','fecha_cierre')) return(!is.na(normalize_date(value)))
  if(field %in% c('monto_min','monto_max')) return(!is.na(normalize_amount(value)))
  if(field=='moneda') return(grepl('^[A-Z]{3}$',value))
  !tolower(value) %in% c('unknown','null','no encontrado')
}
get_overrides <- function() read_config('manual_overrides')$overrides %||% list()
override_for <- function(overrides, table, id, field) {
  Filter(function(x) identical(x$table,table) && identical(x$id,id) && identical(x$field,field),overrides)
}
evidence_valid <- function(item, source_text, url) {
  !is.null(item$quote) && !is.na(item$quote) && nchar(item$quote)>=8 &&
    !is.null(item$url) && identical(normalize_url(item$url),normalize_url(url)) &&
    grepl(item$quote,source_text,fixed=TRUE)
}
field_evidence_valid <- function(item,source_text,url) {
  if(!evidence_valid(item,source_text,url)) return(FALSE)
  # An overhead exclusion does not establish a matching-funds requirement.
  if(identical(item$field,'requiere_cofinanciamiento'))
    return(grepl('co.?financ|cost.?shar|matching|match.?fund|contribution|contrapart|aportes',tolower(item$quote)))
  TRUE
}
record_change <- function(db, run_id, oid,cid,field,old,new,sid,applied,reason) {
  # Including previous applied transitions allows a true A->B->A->B sequence.
  revision <- sum(db$changes$call_id==cid & db$changes$field==field & flag(db$changes$auto_applied),na.rm=TRUE)
  id <- stable_id('change',oid,cid,field,old,new,revision)
  if(!id %in% db$changes$change_id) db$changes <- rbind(db$changes,row('changes',change_id=id,run_id=run_id,opportunity_id=oid,call_id=cid,field=field,old_value=old,new_value=new,source_id=sid,detected_at=now(),auto_applied=applied,review_required=!applied,reason=reason))
  db
}
reconcile <- function(db, source_id, extraction, source_text, run_id, overrides=get_overrides()) {
  si <- match(source_id,db$sources$source_id); src <- db$sources[si,,drop=FALSE]
  ci <- match(src$call_id,db$calls$call_id); oi <- match(src$opportunity_id,db$opportunities$opportunity_id)
  if(is.na(ci)) return(queue_review(db,src$opportunity_id,source_id=source_id,reason='unlinked_source',details='Fuente sin edición asociada.'))
  verified_any <- FALSE
  for(item in extraction$fields %||% list()) {
    f <- item$field; new <- item$value
    if(is.null(new) || is.na(new) || !f %in% c(editable_opportunity,editable_call)) next
    table <- if(f %in% editable_call) 'calls' else 'opportunities'
    ix <- if(table=='calls') ci else oi; id <- db[[table]][[1]][ix]
    old <- db[[table]][[f]][ix]; new <- as.character(new)
    if(!valid_field_value(f,new)) {
      db <- queue_review(db,src$opportunity_id,src$call_id,source_id,'invalid_extracted_value',paste(f,new,sep=': '))
      next
    }
    evidence <- field_evidence_valid(item,source_text,src$url)
    trusted <- flag(src$is_official) && evidence && isTRUE(extraction$high_confidence)
    if(f %in% c('fecha_apertura','fecha_cierre') && is.na(normalize_date(new))) trusted <- FALSE
    if(f %in% c('monto_min','monto_max') && is.na(normalize_amount(new))) trusted <- FALSE
    locked <- length(override_for(overrides,table,id,f))>0
    prior <- db$changes[db$changes$call_id==src$call_id & db$changes$field==f & flag(db$changes$auto_applied) & !is.na(db$changes$source_id),,drop=FALSE]
    prior <- prior[!is.na(prior$change_id),,drop=FALSE]
    discrepancy <- f %in% critical_fields && nrow(prior)>0 && tail(prior$source_id,1)!=source_id
    same <- identical(old,new)
    if(same && trusted) verified_any <- TRUE
    if(same) next
    apply <- trusted && !locked && !discrepancy
    reason <- if(locked) 'manual_override_conflict' else if(discrepancy) 'sources_disagree' else if(!trusted) 'insufficient_official_evidence' else 'official_quoted_evidence'
    # Clearly ineligible discoveries are excluded before insertion; existing records are retained but unpublished.
    db <- record_change(db,run_id,src$opportunity_id,src$call_id,f,old,new,source_id,apply,reason)
    if(apply) {
      db[[table]][[f]][ix] <- new; verified_any <- TRUE
      if(f=='elegibilidad_uchile') {
        db$calls$evidence_source_id[ci] <- source_id
        db$calls$eligibility_evidence[ci] <- item$quote
      }
      if(f=='fecha_cierre') db$calls$closing_evidence[ci] <- item$quote
    } else db <- queue_review(db,src$opportunity_id,src$call_id,source_id,reason,paste(f,':',old,'=>',new))
  }
  if(verified_any) db$calls$last_verified[ci] <- now()
  db$calls$estado_calculado[ci] <- derive_state(db$calls$fecha_apertura[ci],db$calls$fecha_cierre[ci])
  db$calls$review_required[ci] <- as.character(any(db$review_queue$call_id==src$call_id & db$review_queue$status=='pending',na.rm=TRUE))
  db
}
apply_overrides <- function(db,overrides=get_overrides(),run_id='manual') {
  for(x in overrides) {
    if(!x$table %in% c('calls','opportunities') || !x$field %in% c(editable_call,editable_opportunity,'active_record') || !x$field %in% schema[[x$table]]) stop('Override inválido')
    i <- match(x$id,db[[x$table]][[1]])
    if(is.na(i)) stop('Override con ID desconocido: ',x$id)
    old <- db[[x$table]][[x$field]][i]; value <- as.character(x$value %||% NA_character_)
    if(!identical(old,value)) {
      oid <- if(x$table=='calls') db$calls$opportunity_id[i] else x$id
      cid <- if(x$table=='calls') x$id else NA_character_
      db <- record_change(db,run_id,oid,cid,x$field,old,value,x$source_id %||% NA_character_,TRUE,paste('manual:',x$reason))
      db[[x$table]][[x$field]][i] <- value
      if(x$table=='calls' && x$field=='elegibilidad_uchile') {
        db$calls$evidence_source_id[i] <- x$source_id %||% NA_character_
        db$calls$eligibility_evidence[i] <- x$quote %||% NA_character_
      }
      if(x$table=='calls' && x$field=='fecha_cierre') db$calls$closing_evidence[i] <- x$quote %||% NA_character_
    }
  }
  for(i in seq_len(nrow(db$calls))) db$calls$estado_calculado[i] <- derive_state(db$calls$fecha_apertura[i],db$calls$fecha_cierre[i])
  db
}
