# Monitor de oportunidades internacionales FACSO

MVP R-first para migrar, monitorear, descubrir y publicar fondos y estancias de investigación pertinentes a la Universidad de Chile. Usa CSV versionables, HTTP antes de IA, evidencia y revisión humana. El sitio Quarto es estático.

**Estado inicial:** base migrada; información legacy pendiente de verificación web. Los originales en `input/` permanecen intactos. El catálogo no supone vigencia a partir de etiquetas históricas.

## Instalación

Requiere R 4.6.1 y Quarto (también sirve el incluido en RStudio). Desde la raíz:

```r
install.packages('renv', repos='https://cloud.r-project.org')
renv::restore()
```

Alternativa de arranque local: `Rscript scripts/bootstrap.R` instala dependencias en `.tools/R-library`, dentro del proyecto. No versionar esa biblioteca. `renv.lock` fija las versiones; tras cambiar dependencias, actualizar `DESCRIPTION` y ejecutar `Rscript scripts/lock_dependencies.R`. `.Rprofile` activa renv automáticamente. `Rscript scripts/restore_local.R` permite reutilizar los paquetes descargados en la biblioteca aislada.

En este equipo, si R y Quarto no están en PATH:

```powershell
$env:LC_ALL = ''
$env:Path = 'C:\Program Files\R\R-4.6.1\bin;C:\Program Files\RStudio\resources\app\bin\quarto\bin;' + $env:Path
```

## Uso

La migración ya está realizada. El comando de migración **rechaza sobrescribir** una base existente:

```sh
Rscript scripts/migrate_legacy.R
Rscript scripts/update.R --mode monitor --dry-run --mock --limit 3
Rscript scripts/update.R --mode discover --dry-run --mock --limit 5
Rscript scripts/test.R
Rscript scripts/qa.R
Rscript scripts/render_site.R
```

El último comando encuentra el Quarto de RStudio automáticamente en este equipo. Abre `site/_site/index.html` para consultar el resultado. Con R/Quarto y sus bibliotecas configurados también funciona `quarto render site`.

Para probar el render dentro de testthat en PowerShell:

```powershell
$env:RUN_RENDER_TEST = 'true'
Rscript scripts/test.R
```

## API y ejecución real

Copiar `.env.example` a `.env` y completar localmente `OPENAI_API_KEY`, `OPENAI_MODEL` y opcionalmente `OPENAI_MAX_CALLS`. No enviar la clave por chat ni versionarla. El modelo debe admitir Responses, búsqueda web y salidas estructuradas; no se impone un modelo predeterminado.

```sh
Rscript scripts/update.R --mode monitor --dry-run --limit 3
Rscript scripts/update.R --mode discover --dry-run --limit 5
Rscript scripts/update.R --mode full --limit 5
```

Sin `--mock`, dry-run puede hacer llamadas facturables; solo evita persistir canónicos y publicados. El máximo de llamadas es 10 por proceso, sin reintentos API automáticos. No se han ejecutado búsquedas pagadas durante la construcción.

## Archivos y trazabilidad

- `input/`: originales de solo lectura.
- `data/staging/legacy_grants.csv`: copia tabular completa; `legacy_classification.csv`: mapa a filas e IDs.
- `data/canonical/`: oportunidades, ediciones, fuentes, cambios, ejecuciones, revisión y exclusiones. Estos son los datos persistidos principales.
- `data/published/`: dos vistas de gestión regeneradas; contienen los mínimos del PDF.
- `data/fixtures/`: datos simulados exclusivos de pruebas.
- `config/`: familias de consulta, fuentes aprobadas, schema, overrides y exclusiones.
- `R/` y `scripts/`: lógica y CLI. `site/`: fuentes del sitio. `site/_site/`: HTML generado, no versionado.
- `docs/initial_audit.md`, `docs/migration_report.md`, `docs/architecture.md`: auditoría y decisiones.

Nunca interpretar `last_checked` como verificación del dato: esa distinción corresponde a `last_verified` y evidencia. Las fechas sin respaldo quedan como texto. NA interno se convierte en «No encontrado» solo en vistas de gestión.

## Revisión, overrides y exclusiones

Revisar `data/canonical/review_queue.csv`. Los motivos separan dudas legacy, duplicados, fuentes caídas y contradicciones. Una URL caída se conserva y requiere buscar una nueva fuente oficial. Para corregir un valor usar `config/manual_overrides.yml` con tabla, ID, campo, valor y razón; hay un ejemplo comentado. Para elegibilidad Sí añadir `source_id` oficial y `quote`. Para publicar un cierre en próximos cierres añadir cita al override. El pipeline valida antes de persistir y rechaza IDs inexistentes.

Agregar dominios oficiales solo tras comprobar que pertenecen al financiador/institución. `config/exclusions.yml` bloquea URLs o dominios para descubrimiento; `excluded_candidates.csv` conserva los descartes concretos. No fusionar duplicados con datos distintos sin revisar sus versiones y referencias. Después de una resolución humana se puede marcar el item como `resolved` y ejecutar QA.

## GitHub Actions y Pages (pendientes de autorización)

Los workflows están preparados pero desactivados por variables. No se ha hecho push ni habilitado Pages. Cuando se autorice:

1. Crear o elegir repositorio GitHub y subir el proyecto a `main`.
2. Configurar el secret `OPENAI_API_KEY` y la variable `OPENAI_MODEL`.
3. Revisar límites API y poner `ENABLE_AUTOMATION=true` para activar actualización martes/viernes y descubrimiento domingo (horario UTC).
4. Configurar Pages con fuente GitHub Actions y `ENABLE_PAGES=true`.

La actualización solo añade `data/canonical` y `data/published` al commit. Pages usa artefacto de HTML y despliegue oficial. `workflow_run` permite publicar después de la actualización con GITHUB_TOKEN, cuyo push por sí solo no dispara otro workflow. Los jobs de publicación no necesitan la clave OpenAI. La cola de revisión, exclusiones y configuración no se copian al sitio.

## Recuperación

No ejecutar dos escritores locales a la vez. Ante interrupción brusca revisar `data/.previous`, `.transaction` y `.lock` antes de reintentar; conservar copia y recuperar la generación anterior completa. No borrar canónicos por un fallo de red. Ver detalles y límites en `docs/architecture.md`.
