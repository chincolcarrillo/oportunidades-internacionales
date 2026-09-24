minimum_funds <- fields('convocatoria programa institucion_financiante pais region idiomas area_disciplinar objetivo alcance perfil_investigador_elegible requiere_cofinanciamiento monto_financiamiento moneda gastos_financiables duracion_proyecto fecha_apertura fecha_cierre frecuencia_apertura_llamado enlaces elegibilidad_uchile observaciones_dudas')
minimum_stays <- fields('convocatoria programa institucion_financiante institucion_destino pais region perfil_investigador_elegible requisitos_idiomas requisitos_contraparte area_disciplinar objetivo alcance duracion_estancia periodo_estancia fecha_apertura fecha_cierre requiere_cofinanciamiento gastos_cubiertos frecuencia_apertura_llamado enlaces elegibilidad_uchile observaciones_dudas')
published_tables <- function(db) {
  x <- merge(db$calls,db$opportunities,by='opportunity_id',suffixes=c('','.opportunity'),sort=FALSE)
  x <- x[flag(x$active_record) & x$elegibilidad_uchile %in% c('Sí','No claro (check)'),,drop=FALSE]
  x$enlaces <- vapply(x$call_id,function(id) paste(unique(db$sources$url[db$sources$call_id==id & !is.na(db$sources$call_id)]),collapse=' | '),character(1))
  x$idiomas <- x$idiomas_postulacion; x$requisitos_idiomas <- x$idiomas_postulacion
  x$monto_financiamiento <- x$monto_financiamiento_texto
  labels <- c(upcoming='Próxima',open='Abierta',closed='Cerrada',rolling='Permanente',inactive='No vigente',unknown='No claro (check)')
  x$estado_actual <- vapply(seq_len(nrow(x)),function(i) unname(labels[derive_state(x$fecha_apertura[i],x$fecha_cierre[i],rolling=x$estado_calculado[i]=='rolling',inactive=x$estado_calculado[i]=='inactive')]),character(1))
  x$ultima_verificacion <- x$last_verified; x$id <- x$call_id
  for (f in c('fecha_apertura','fecha_cierre')) x[[f]][is.na(x[[f]])] <- x[[paste0(f,'_texto')]][is.na(x[[f]])]
  make <- function(types,cols) {
    y <- x[x$tipo_oportunidad %in% types,c(cols,'etapa_carrera','tipo_investigacion','estado_actual','ultima_verificacion','id'),drop=FALSE]
    for (n in names(y)) y[[n]][is.na(y[[n]]) | y[[n]]==''] <- if(n=='elegibilidad_uchile') 'No claro (check)' else 'No encontrado'
    y
  }
  list(fondos_investigacion=make(c('fondo','ambos'),minimum_funds),estancias_investigacion=make(c('estancia','ambos'),minimum_stays))
}
save_db <- function(db, root='data') {
  validate_db(db)
  dir.create(root,showWarnings=FALSE,recursive=TRUE)
  lock <- file.path(root,'.lock')
  if (!dir.create(lock,showWarnings=FALSE)) stop('Otra ejecución mantiene el bloqueo de datos.')
  on.exit(unlink(lock,recursive=TRUE),add=TRUE)
  stage <- file.path(root,'.transaction'); dir.create(stage,recursive=TRUE,showWarnings=FALSE)
  # Stage a complete generation before replacing; rollback handles ordinary write errors.
  for(n in names(db)) write_csv(db[[n]],file.path(stage,'canonical',paste0(n,'.csv')))
  for(n in names(published_tables(db))) write_csv(published_tables(db)[[n]],file.path(stage,'published',paste0(n,'.csv')))
  old <- file.path(root,'.previous')
  if(dir.exists(old)) stop('Existe respaldo .previous; revisar recuperación antes de continuar.')
  dir.create(old)
  moved <- character(); installed <- character(); ok <- FALSE
  on.exit({
    if(!ok) {
      for(n in installed) unlink(file.path(root,n),recursive=TRUE)
      for(n in moved) file.rename(file.path(old,n),file.path(root,n))
    }
    if(ok || !length(list.files(old))) unlink(old,recursive=TRUE)
    unlink(stage,recursive=TRUE)
  },add=TRUE)
  for(n in c('canonical','published')) {
    if(dir.exists(file.path(root,n))) {
      if(!file.rename(file.path(root,n),file.path(old,n))) stop('No se pudo respaldar ',n)
      moved <- c(moved,n)
    }
    if(!file.rename(file.path(stage,n),file.path(root,n))) stop('No se pudo instalar ',n)
    installed <- c(installed,n)
  }
  ok <- TRUE
}
