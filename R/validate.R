validate_db <- function(db, verbose=FALSE) {
  errors <- character(); warnings <- character()
  err <- function(x) errors <<- c(errors,x)
  for(n in names(schema)) {
    if(!identical(names(db[[n]]),schema[[n]])) err(paste('Esquema incompatible:',n))
    key <- db[[n]][[1]]
    if(anyNA(key) || anyDuplicated(key)) err(paste('IDs ausentes/duplicados:',n))
  }
  if(length(errors)) stop(paste(errors,collapse='\n'))
  decisions <- db$agent_decisions
  if(any(!decisions$status %in% c('applied','unchanged','excluded','review','retry','stale'))) err('Estado de decisión inválido')
  if(any(!decisions$role %in% c('monitor','discover'))) err('Rol de decisión inválido')
  if(anyNA(decisions$attempts) || any(!grepl('^[1-9][0-9]*$',decisions$attempts))) err('Intentos de decisión inválidos')
  if(anyNA(decisions$evidence_hash) || any(!grepl('^[a-f0-9]{64}$',decisions$evidence_hash))) err('Hash de evidencia inválido')
  o <- db$opportunities; c <- db$calls; s <- db$sources
  if(any(!c$opportunity_id %in% o$opportunity_id) || any(!s$opportunity_id %in% o$opportunity_id)) err('Claves opportunity_id rotas')
  if(any(!is.na(s$call_id) & !s$call_id %in% c$call_id)) err('Claves call_id rotas')
  linked <- match(s$call_id,c$call_id)
  if(any(!is.na(linked) & s$opportunity_id != c$opportunity_id[linked],na.rm=TRUE)) err('Fuente enlazada a instrumento incorrecto')
  if(any(!grepl('^https?://[^ /]+',s$url) | is.na(s$url))) err('URLs inválidas')
  enums <- list(tipo_oportunidad=c('fondo','estancia','ambos'),frecuencia_normalizada=c('anual','dos_veces_al_ano','cada_dos_anos','permanente','puntual','irregular','no_encontrado','no_claro'))
  for(n in names(enums)) if(any(!is.na(o[[n]]) & !o[[n]] %in% enums[[n]])) err(paste('Enum inválido',n))
  if(any(!c$elegibilidad_uchile %in% c('Sí','No claro (check)','No'))) err('Elegibilidad inválida')
  if(any(!c$estado_calculado %in% c('open','closed','upcoming','rolling','inactive','unknown'))) err('Estado inválido')
  for(n in c('fecha_apertura','fecha_cierre')) if(any(!is.na(c[[n]]) & is.na(vapply(c[[n]],normalize_date,character(1))))) err(paste('Fecha inválida:',n))
  if(any(c$fecha_cierre < c$fecha_apertura,na.rm=TRUE)) err('Cierre anterior a apertura')
  if(any((!is.na(c$monto_min) | !is.na(c$monto_max)) & (is.na(c$moneda) | !grepl('^[A-Z]{3}$',c$moneda)))) err('Monto numérico sin moneda ISO')
  for(n in c('monto_min','monto_max')) if(any(!is.na(c[[n]]) & is.na(suppressWarnings(as.numeric(c[[n]]))))) err('Monto inválido')
  if(any(as.numeric(c$monto_min)>as.numeric(c$monto_max),na.rm=TRUE)) err('Monto mínimo superior a máximo')
  if(any(c$estado_calculado=='open' & c$fecha_cierre < as.character(today()),na.rm=TRUE)) err('Convocatoria abierta con cierre pasado')
  for(i in which(c$elegibilidad_uchile=='Sí')) {
    src <- match(c$evidence_source_id[i],s$source_id)
    if(is.na(src) || !flag(s$is_official[src]) || is.na(c$eligibility_evidence[i]) || !nzchar(c$eligibility_evidence[i])) err(paste('Sí sin evidencia oficial:',c$call_id[i]))
  }
  for(n in c('changes','review_queue')) {
    t <- db[[n]]
    if(any(!is.na(t$opportunity_id) & !t$opportunity_id %in% o$opportunity_id)) err(paste('FK rota',n))
    if(any(!is.na(t$call_id) & !t$call_id %in% c$call_id)) err(paste('FK call rota',n))
    if(any(!is.na(t$source_id) & !t$source_id %in% s$source_id)) err(paste('FK source rota',n))
  }
  p <- published_tables(db)
  for(n in names(p)) {
    required <- if(n=='fondos_investigacion') minimum_funds else minimum_stays
    if(!all(required %in% names(p[[n]]))) err(paste('Faltan mínimos',n))
    if(any(p[[n]]$enlaces=='No encontrado')) err(paste('Publicación sin fuente',n))
  }
  if(any(db$review_queue$reason=='possible_duplicate')) warnings <- c(warnings,'Hay duplicados probables pendientes de revisión.')
  if(any(is.na(c$last_verified))) warnings <- c(warnings,sprintf('%s convocatorias aún no verificadas.',sum(is.na(c$last_verified))))
  if(verbose) cat(paste(c(sprintf('QA: %s errores, %s advertencias.',length(errors),length(warnings)),warnings,errors),collapse='\n'),'\n')
  if(length(errors)) stop(paste(errors,collapse='\n'))
  invisible(warnings)
}
