# Monitor de oportunidades FACSO

- Construir y mantener un monitor internacional de fondos y estancias para UChile.
- R-first, CSV canónico, Quarto estático y dependencias con renv.
- Los archivos de input son de solo lectura: nunca modificar los originales legacy.
- No inventar datos. Priorizar evidencia oficial y conservar procedencia y dudas.
- No borrar registros ante errores HTTP. Validar antes de persistir.
- Los manual overrides prevalecen; contradicciones pasan a revisión.
- Los tests usan fixtures sin Internet ni consumo de API.
- Ejecutar tests y QA antes de considerar terminado un cambio; comprobar render Quarto.
- Mantener compatibilidad con GitHub Actions y documentar cambios de esquema.
- No push, activar Pages ni búsquedas pagadas masivas sin autorización explícita.
