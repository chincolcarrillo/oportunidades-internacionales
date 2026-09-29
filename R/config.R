`%||%` <- function(x, y) if (is.null(x) || !length(x) || all(is.na(x))) y else x
now <- function() format(Sys.time(), '%Y-%m-%dT%H:%M:%SZ', tz='UTC')
today <- function() as.Date(format(Sys.time(), '%Y-%m-%d', tz='America/Santiago'))
fields <- function(x) strsplit(x, ' ', fixed=TRUE)[[1]]
schema <- list(
  opportunities=fields('opportunity_id tipo_oportunidad convocatoria programa institucion_financiante institucion_destino pais region idiomas_postulacion area_disciplinar objetivo alcance perfil_investigador_elegible etapa_carrera tipo_investigacion requisitos_contraparte rol_permitido_para_postulante frecuencia_apertura_llamado frecuencia_normalizada first_seen last_seen active_record legacy_source_id'),
  calls=fields('call_id opportunity_id edicion fecha_apertura fecha_cierre fecha_apertura_texto fecha_cierre_texto monto_financiamiento_texto monto_min monto_max moneda requiere_cofinanciamiento gastos_financiables gastos_cubiertos duracion_proyecto duracion_estancia periodo_estancia elegibilidad_uchile estado_fuente estado_calculado observaciones_dudas first_seen last_verified review_required evidence_source_id eligibility_evidence closing_evidence'),
  sources=fields('source_id opportunity_id call_id url source_role source_priority is_official domain last_checked http_status content_hash extracted_hash last_changed notes'),
  changes=fields('change_id run_id opportunity_id call_id field old_value new_value source_id detected_at auto_applied review_required reason'),
  runs=fields('run_id started_at finished_at mode sources_checked sources_changed candidates_found records_added records_updated review_items_created errors status'),
  review_queue=fields('review_id opportunity_id call_id source_id reason details created_at status'),
  excluded_candidates=fields('candidate_id convocatoria institucion_financiante url reason first_seen'),
  agent_decisions=fields('proposal_id role run_id decided_at status reason attempts evidence_hash'))
empty_table <- function(name) as.data.frame(setNames(rep(list(character()), length(schema[[name]])), schema[[name]]), stringsAsFactors=FALSE)
new_db <- function() setNames(lapply(names(schema), empty_table), names(schema))
row <- function(table, ...) {
  x <- setNames(rep(list(NA_character_), length(schema[[table]])), schema[[table]])
  values <- list(...)
  stopifnot(all(names(values) %in% names(x)))
  for (n in names(values)) x[[n]] <- as.character(values[[n]] %||% NA_character_)
  as.data.frame(x, stringsAsFactors=FALSE)
}
load_db <- function(path='data/canonical') {
  if(dir.exists(file.path(dirname(path),'.lock')) || dir.exists(file.path(dirname(path),'.previous'))) stop('Datos en transacción o recuperación pendiente; no se leerá una generación parcial.')
  db <- new_db()
  for (n in names(db)) if (file.exists(file.path(path,paste0(n,'.csv')))) db[[n]] <- read.csv(file.path(path,paste0(n,'.csv')), colClasses='character', na.strings='', check.names=FALSE, fileEncoding='UTF-8')
  db
}
write_csv <- function(x, path) {
  dir.create(dirname(path), recursive=TRUE, showWarnings=FALSE)
  write.csv(x, path, row.names=FALSE, na='', fileEncoding='UTF-8')
}
read_config <- function(name) yaml::read_yaml(file.path('config',paste0(name,'.yml')))
flag <- function(x) !is.na(x) & toupper(x) == 'TRUE'
