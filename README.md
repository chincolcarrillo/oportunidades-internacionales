# Monitor de oportunidades internacionales FACSO

Sistema R-first de descubrimiento, vigilancia y curaduría para fondos y estancias
pertinentes a UChile. CSV canónico, evidencia oficial, Quarto estático y renv.
La propietaria decide cuándo desplegar; las actualizaciones de datos no publican.

**Empieza aquí:** [Guía paso a paso para la propietaria](docs/getting-started-agents.md).
[Arquitectura y esquema v2](docs/three-agents.md).

## Tres roles

| Rol | Comando | Resultado |
|---|---|---|
| Descubrimiento | `Rscript scripts/agent.R --role discover --limit 5` | Candidatos con evidencia en la cola |
| Vigilancia | `Rscript scripts/agent.R --role monitor --limit 200` | Observaciones de fuentes conocidas |
| Curaduría | `Rscript scripts/agent.R --role curate --limit 200` | Base validada, decisiones e historial |

Los dos productores nunca guardan la base. El curador es el único escritor de
producción. Los contratos en docs/agents describen cómo trabajar con cada rol.
El mantenimiento del script se realiza con un asistente y pruebas; el cron no
reescribe código automáticamente. Los casos ambiguos permanecen pendientes.

## Instalación y pruebas

R 4.6.1, Quarto y dependencias fijadas en renv.lock:

```r
install.packages('renv', repos='https://cloud.r-project.org')
renv::restore()
```

```sh
Rscript scripts/test.R
Rscript scripts/demo_agents.R
Rscript scripts/qa.R
Rscript scripts/render_site.R
Rscript scripts/agent.R --role monitor --mock --dry-run --limit 3
Rscript scripts/agent.R --role discover --mock --dry-run --limit 2
```

La demo usa fixtures y directorio temporal; no llama a Internet/API ni altera el
catálogo. El render genera site/_site/index.html y encuentra el Quarto de RStudio
en Windows. Para incluirlo en testthat definir RUN_RENDER_TEST=true.

Alternativa local existente: scripts/bootstrap.R instala en .tools/R-library;
scripts/restore_local.R reutiliza esa biblioteca. En este equipo, si falta PATH:

```powershell
$env:LC_ALL = ''
$env:Path = 'C:\Program Files\R\R-4.6.1\bin;C:\Program Files\RStudio\resources\app\bin\quarto\bin;' + $env:Path
```

## Ejecución real

Definir OPENAI_API_KEY, OPENAI_MODEL y OPENAI_MAX_CALLS en el entorno o .env local
ignorado. No versionar claves. Descubrimiento usa búsqueda; curaduría extrae hechos
con citas y valida. Vigilancia sólo usa HTTP.

--dry-run evita persistir propuestas/canónicos, pero sin --mock puede consumir API.
Mock exige dry-run. Los límites son solicitudes por proceso, no topes monetarios.

La CLI anterior update.R --mode monitor/discover sólo produce propuestas.
--mode full se retiró: ejecutar los roles de forma explícita.

## GitHub

- **Checks (offline)**: tests, demo, QA y render; sin secretos API.
- **Run three agents**: roles separados, evidencia y preview; calendario optativo.
- **Publish site**: exclusivamente manual por DEPLOY_OWNER, con SHA completo.

Sin AUTO_COMMIT_DATA=true los resultados se entregan como artefactos por 30 días.
Con esa variable, se guardan sólo datos/evidencia tras controles, si main no cambió.
ENABLE_AUTOMATION=true activa el calendario. ENABLE_PAGES=true habilita publicación
manual; no dispara despliegues. Configuración detallada en la guía.

No se hizo push ni se habilitaron automatizaciones o Pages durante esta migración.

## Archivos y reglas

- input/: originales legacy de sólo lectura.
- data/canonical/: oportunidades, ediciones, fuentes, cambios, ejecuciones, revisión,
  exclusiones y nuevo agent_decisions.csv.
- data/proposals/: observaciones JSON versionadas, con texto fuente y hash.
- data/agent-evidence/: extracciones estructuradas versionadas.
- data/published/: vistas de gestión regeneradas.
- config/: dominios aprobados, consultas, exclusiones, schema y manual_overrides.yml.
- docs/agents/: contratos de descubrimiento, vigilancia y curaduría.

Los overrides prevalecen. HTTP fallido no borra registros. last_checked indica
intento; last_verified requiere evidencia. No inventar fechas ni elegibilidad.
Sólo los datos pertinentes llegan al sitio: colas y evidencia no se copian al HTML.

La migración legacy no equivale a una verificación web: QA sigue señalando registros
sin verificar y duplicados pendientes. Ver docs/migration_report.md.

## Recuperación

No ejecutar escritores locales simultáneos. Ante .previous, .transaction o .lock,
detener la ejecución y revisar una recuperación completa antes de reintentar.
No borrar esos directorios a ciegas. Los límites transaccionales de save_db siguen
descritos en docs/architecture.md. Propuestas y decisiones permiten auditar el lote.
