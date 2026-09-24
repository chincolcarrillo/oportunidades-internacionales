read_legacy <- function(path='input/base_grants_investigacion_Chile.xlsm') {
  x <- as.data.frame(readxl::read_excel(path, sheet='grants_investigacion', col_types='text', .name_repair='unique'),stringsAsFactors=FALSE)
  x <- x[,!vapply(x,function(z) all(is.na(z)),logical(1)),drop=FALSE]
  x[rowSums(!is.na(x))>0,,drop=FALSE]
}
classify_legacy <- function(name, description='') {
  z <- norm(paste(name,description))
  if (grepl('publication subsidy|research prize|grant opportunities|convocatorias de investigacion clacso',norm(name))) return('revisar')
  stay <- grepl('estancia|residencia|visiting|visitante|travelling fellowship|post doctoral study|fellowship for postdoctoral|fellowship for field|research fellowship hamburg|japanese studies fellowship|staff exchanges',z)
  project <- grepl('financia proyectos|proyectos de investigacion|research projects',z)
  if (stay && project) 'ambos' else if (stay) 'estancia' else if (grepl('fellowship|scholar grants',norm(name))) 'revisar' else 'fondo'
}
migrate_legacy <- function(path='input/base_grants_investigacion_Chile.xlsm') {
  raw <- read_legacy(path); db <- new_db(); stamp <- now(); report <- list()
  for (i in seq_len(nrow(raw))) {
    original <- raw[i,,drop=FALSE]; x <- lapply(original,clean_missing)
    oid <- stable_id('opp',norm(x$instrumento),norm(x$institucion_financiante))
    lid <- stable_id('legacy',jsonlite::toJSON(original,na='null',auto_unbox=TRUE))
    kind <- classify_legacy(x$instrumento,x$objetivo_y_alcance_breve)
    urls <- split_urls(x$enlaces)
    matches <- duplicate_matches(db,x$instrumento,x$institucion_financiante,urls)
    report[[i]] <- data.frame(legacy_source_id=lid,opportunity_id=oid,excel_row=i+1,classification=kind,duplicate_candidates=paste(unique(matches$opportunity_id),collapse=' | '))
    if (!oid %in% db$opportunities$opportunity_id) {
      db$opportunities <- rbind(db$opportunities,row('opportunities',opportunity_id=oid,
        tipo_oportunidad=if(kind %in% c('revisar','fuera_de_alcance')) NA_character_ else kind,
        convocatoria=x$instrumento, programa=x$institucion_madre_o_programa_paraguas %||% x$instrumento,
        institucion_financiante=x$institucion_financiante, region=x$Origen_financiamiento,
        area_disciplinar=x$area_disciplinar,objetivo=x$objetivo_y_alcance_breve,
        perfil_investigador_elegible=x$perfil_investigador_elegible,etapa_carrera=x$etapa_carrera,
        tipo_investigacion=x$tipo_investigacion,rol_permitido_para_postulante=x$rol_permitido_para_postulante,
        frecuencia_apertura_llamado=x$frecuencia_apertura_llamado,frecuencia_normalizada=normalize_frequency(x$frecuencia_apertura_llamado),
        first_seen=stamp,last_seen=stamp,active_record=kind %in% c('fondo','estancia','ambos'),legacy_source_id=lid))
    } else {
      j <- match(oid,db$opportunities$opportunity_id)
      db$opportunities$legacy_source_id[j] <- paste(db$opportunities$legacy_source_id[j],lid,sep=' | ')
    }
    # Separate legacy assertions preserve conflicting versions; no invented edition/year.
    cid <- stable_id('call',oid,lid)
    notes <- paste(na.omit(c(x$observaciones_dudas,
      '(check) Semilla legacy sin verificación web actual. Región provisional; objetivo/alcance conservado sin separación inferida.',
      paste('Elegibilidad legacy Chile:',x$elegibilidad_chile,'; universidad:',x$elegibilidad_universidad_chilena))),collapse=' ')
    if (!cid %in% db$calls$call_id) db$calls <- rbind(db$calls,row('calls',call_id=cid,opportunity_id=oid,edicion=paste0('legacy_sin_edicion_',substr(lid,8,15)),
      fecha_cierre_texto=x$fecha_convocatoria,monto_financiamiento_texto=x$monto_financiamiento,
      moneda=if(!is.na(x$moneda) && grepl('^[A-Z]{3}$',x$moneda)) x$moneda else NA_character_,
      requiere_cofinanciamiento=x$requiere_cofinanciamiento,gastos_financiables=x$gastos_financiables,
      duracion_proyecto=if(kind %in% c('fondo','ambos')) x$duracion_financiamiento else NA_character_,
      duracion_estancia=if(kind %in% c('estancia','ambos')) x$duracion_financiamiento else NA_character_,
      elegibilidad_uchile='No claro (check)',estado_fuente=x$estado_actual,estado_calculado='unknown',observaciones_dudas=notes,first_seen=stamp,review_required=TRUE))
    for (u in urls) {
      sid <- stable_id('src',oid,cid,u)
      if (!sid %in% db$sources$source_id) db$sources <- rbind(db$sources,row('sources',source_id=sid,opportunity_id=oid,call_id=cid,url=u,source_role='legacy_unverified',source_priority=6,is_official=FALSE,domain=domain_of(u),notes='Oficialidad pendiente de verificación.'))
    }
    db <- queue_review(db,oid,cid,reason=if(kind=='revisar') 'legacy_scope' else 'legacy_verification',details=notes)
    if (nrow(matches)) db <- queue_review(db,oid,cid,reason='possible_duplicate',details=paste(unique(matches$opportunity_id),collapse=' | '))
  }
  list(db=db,raw=raw,classification=do.call(rbind,report))
}
