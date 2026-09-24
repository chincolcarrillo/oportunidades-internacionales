source('scripts/load.R')
if (file.exists('data/canonical/opportunities.csv')) stop('Migración ya realizada. No se sobrescribirá la base canónica; use otro directorio para ensayar una nueva migración.')
result <- migrate_legacy()
write_csv(result$raw,'data/staging/legacy_grants.csv')
write_csv(result$classification,'data/staging/legacy_classification.csv')
save_db(result$db)
writeLines(c('# Informe de migración', '',
 sprintf('Migrados %s registros legacy, %s instrumentos y %s versiones de convocatorias sin edición verificada.',nrow(result$raw),nrow(result$db$opportunities),nrow(result$db$calls)),
 sprintf('%s vínculos de procedencia. %s items de revisión.',nrow(result$db$sources),nrow(result$db$review_queue)),
 '', 'La identidad exacta institución + instrumento comparte opportunity_id. Se conservan las versiones distintas como calls provisionales hasta reconciliar edición y evidencia. Los candidatos similares no se fusionan.',
 'Las fechas narrativas permanecen como texto y no alimentan próximos cierres. Ninguna elegibilidad legacy se promueve a Sí.',
 'La clasificación y correspondencia a la fila de Excel están en data/staging/legacy_classification.csv. El contenido original se conserva íntegro en legacy_grants.csv.',
 '',capture.output(table(result$classification$classification))), 'docs/migration_report.md',useBytes=TRUE)
cat('Migración y exportaciones completas.\n')
