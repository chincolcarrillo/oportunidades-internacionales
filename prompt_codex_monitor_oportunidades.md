# Prompt maestro para Codex: monitor de fondos y estancias internacionales

Quiero que construyas, dentro de este repositorio local, un MVP funcional y mantenible para **mantener y publicar automáticamente una base de datos de oportunidades internacionales de financiamiento para investigación y estancias de investigación relevantes para la Facultad de Ciencias Sociales de la Universidad de Chile**.

Actúa como un/a senior data engineer y desarrollador/a R/Quarto. Prioriza trazabilidad, reproducibilidad, simplicidad operativa y facilidad de mantenimiento por sobre una arquitectura sofisticada.

## 1. Antes de programar

1. Inspecciona primero todo el repositorio y adapta tu solución a cualquier estructura o convención ya existente.
2. Localiza estos dos archivos de insumo, buscándolos recursivamente si no están en la raíz:
   - `base_grants_investigacion_Chile.xlsm`
   - `Mínimos de la base de datos compartida.pdf`
3. **No modifiques ni sobrescribas esos archivos originales.** Trátalos como insumos legacy de solo lectura.
4. Lee ambos archivos antes de tomar decisiones de modelamiento.
5. Resume en `docs/initial_audit.md`:
   - estructura y número de registros/columnas de la base legacy;
   - campos existentes;
   - campos faltantes respecto del documento de mínimos;
   - campos actuales que conviene conservar aunque no sean mínimos;
   - duplicados exactos y posibles duplicados;
   - inconsistencias de vocabulario/codificación;
   - registros que parecen fondos, estancias, ambos o potencialmente fuera de alcance.
6. Si hay una decisión de arquitectura menor que puedas resolver razonablemente, resuélvela y documéntala. No me detengas con preguntas innecesarias.
7. No hagas `git push`, no actives GitHub Pages y no ejecutes búsquedas pagadas masivas sin mi autorización. Sí puedes crear todos los archivos, workflows y configuraciones necesarios.

## 2. Objetivo del sistema

El sistema debe resolver cuatro funciones:

1. **Migrar y normalizar** la base legacy sin perder información.
2. **Monitorear oportunidades ya conocidas** para detectar cambios en fechas, bases, montos, requisitos, elegibilidad, estado y enlaces.
3. **Descubrir oportunidades nuevas** que todavía no estén en la base.
4. **Publicar automáticamente un sitio Quarto estático**, fácil de revisar por equipos de gestión, con información actualizada, filtros y trazabilidad.

La lógica general debe ser:

`fuentes web -> descubrimiento/monitoreo -> extracción estructurada -> validación -> deduplicación/reconciliación -> base canónica -> registro de cambios -> exportaciones -> sitio Quarto`

No quiero que un modelo de IA “reconstruya la base completa” en cada ejecución. La IA debe ser un componente acotado del pipeline; la persistencia, validación, comparación y publicación deben ser determinísticas.

## 3. Definición sustantiva del universo

### 3.1 Elegibilidad

El universo prioritario son oportunidades a las que puedan postular investigadores/as:

- residentes en Chile;
- asociados/as a una universidad chilena;
- ya sea como investigador/a principal/director/a del proyecto o como investigador/a socio/a, co-investigador/a o rol equivalente.

La variable final `elegibilidad_uchile` debe reflejar explícitamente si un/a investigador/a de la Universidad de Chile puede postular.

En la base publicada usar:
- `Sí`
- `No claro (check)`

Si una oportunidad es **claramente no elegible**, no debe incorporarse a la base publicada; debe quedar en una tabla de exclusiones con la razón.

### 3.2 Fondos de investigación

Considera como fondo de investigación una convocatoria, fondo, instrumento o programa que entregue recursos financieros para desarrollar un proyecto de investigación y que pueda financiar, entre otros:

- personal de apoyo;
- levantamiento de información;
- trabajo de campo;
- bases de datos;
- libros, bibliografía o materiales;
- equipamiento;
- software;
- servicios técnicos;
- análisis;
- traducción, edición o publicación asociada al proyecto;
- otras actividades o gastos operativos directamente vinculados con la investigación.

No incluyas automáticamente premios honoríficos, subsidios exclusivamente de publicación, viajes a congresos sin componente de investigación u otros instrumentos que no financien realmente investigación. Si un registro legacy es dudoso, envíalo a revisión en vez de borrarlo.

### 3.3 Estancias

Considera como estancia un periodo temporal presencial en que un/a investigador/a o estudiante doctoral trabaja en una universidad, centro, archivo, laboratorio u otra institución externa, con subsidio o beca que cubra total o parcialmente los gastos.

Puede incluir:

- estancias de investigación;
- residencias de escritura;
- movilidad docente;
- estadías postdoctorales;
- visiting researcher / visiting scholar;
- becas para uso de archivos, bibliotecas o laboratorios;
- programas de formación metodológica;
- estancias para preparar proyectos conjuntos.

### 3.4 Áreas disciplinares

Incluye oportunidades abiertas a una o más de estas áreas, sin exigir que sean exclusivas:

- Humanidades
- Ciencias Sociales
- Estudios de género
- Estudios de infancias
- Estudios de pueblos indígenas
- Estudios del trabajo
- Estudios de América Latina
- Trabajo Social
- Sociología
- Antropología
- Psicología
- Arqueología
- Paleobiología
- Educación
- convocatorias interdisciplinarias, transdisciplinarias o generales donde estas áreas puedan postular.

No excluyas una convocatoria solo porque también financie otras disciplinas.

## 4. Estrategia técnica del MVP

Quiero una solución **R-first**, porque es el lenguaje que mantendré posteriormente.

Usa:

- R para ingestión, scraping simple, transformación, validación, deduplicación, reconciliación y exportación;
- Quarto para el sitio;
- `renv` para dependencias reproducibles;
- CSV como formato canónico versionable y revisable en Git;
- JSON/JSONL para resultados estructurados, evidencia o fixtures cuando sea útil;
- HTML estático como output del sitio.

No introduzcas PostgreSQL, Supabase, Shiny, Docker, Selenium, Playwright ni una infraestructura de servidor en el MVP, salvo que haya una razón técnica indispensable. Si una página requiere JavaScript y no se puede leer de forma razonable, usa preferentemente otra fuente oficial o el componente de búsqueda web antes de añadir browser automation.

Para leer el `.xlsm`, utiliza una librería R que soporte el formato de manera segura (por ejemplo `readxl` si funciona correctamente con el archivo o `openxlsx2`). El archivo debe permanecer intacto.

## 5. Uso de OpenAI para búsqueda y extracción

El sistema podrá usar la API de OpenAI para dos funciones:

1. **descubrimiento web** de nuevas oportunidades;
2. **extracción estructurada** desde información web no estructurada.

Antes de implementar esta integración, revisa la documentación oficial vigente de OpenAI. Para una integración nueva, usa la API actualmente recomendada y herramientas vigentes; no copies ejemplos obsoletos.

Diseña la integración para:

- usar búsqueda web cuando corresponda;
- pedir outputs estructurados contra un JSON Schema;
- recuperar y guardar las fuentes utilizadas;
- leer `OPENAI_API_KEY` desde variables de entorno/GitHub Secrets;
- leer el modelo desde `OPENAI_MODEL`, sin dejar la elección crítica del modelo dispersa por el código;
- poder cambiar de modelo sin cambiar la lógica del pipeline;
- evitar llamadas al modelo si no son necesarias.

Crea `.env.example`, pero nunca guardes claves reales.

Implementa un modo mock/fixture para que los tests no consuman API.

## 6. Principio de eficiencia: primero HTTP, después IA

Para oportunidades ya conocidas:

1. consultar directamente las URLs registradas;
2. guardar código HTTP, fecha de consulta y hash del contenido relevante;
3. si el contenido no cambió, no volver a extraer con IA;
4. si cambió, volver a extraer solo esa oportunidad;
5. comparar los valores extraídos con los valores canónicos;
6. registrar los cambios.

Para descubrimiento:

1. ejecutar búsquedas amplias según las familias institucionales definidas abajo;
2. identificar candidatos;
3. comprobar si ya existen;
4. buscar y verificar una fuente oficial;
5. extraer la información estructurada;
6. validar elegibilidad y alcance;
7. incorporar automáticamente solo los casos suficientemente respaldados;
8. enviar los casos ambiguos a `review_queue`.

## 7. Familias de fuentes para descubrimiento

Construye `config/discovery_queries.yml` y `config/sources.yml`.

La búsqueda debe cubrir sistemáticamente:

- agencias nacionales de investigación;
- ministerios o secretarías sectoriales;
- agencias de cooperación internacional;
- organismos multilaterales;
- fundaciones filantrópicas;
- fundaciones científicas o culturales;
- centros de investigación;
- institutos de estudios avanzados;
- universidades;
- escuelas, facultades o departamentos;
- programas regionales o internacionales de investigación;
- redes académicas que administren fondos;
- embajadas o instituciones binacionales;
- organizaciones internacionales con convocatorias académicas;
- programas sobre educación, cultura, patrimonio, democracia, desigualdad, desarrollo, derechos humanos, salud mental, infancia, género, medioambiente, territorio y otros temas pertinentes.

Usa búsquedas en español e inglés y, cuando sea útil, en francés y portugués.

La cobertura es internacional. Incluye oportunidades bilaterales o multilaterales en que Chile sea elegible. No priorices fondos nacionales chilenos sin un componente internacional.

## 8. Jerarquía de fuentes y regla de verificabilidad

Prioridad de evidencia:

1. página oficial específica de la convocatoria;
2. bases, guidelines o PDF oficial;
3. página oficial del programa o institución financiadora;
4. página oficial de institución socia;
5. fuente secundaria confiable;
6. agregadores u otras fuentes secundarias.

Las fechas, elegibilidad, montos y requisitos críticos no deben considerarse plenamente verificados basándose únicamente en una fuente secundaria.

Cuando exista ambigüedad, usa `No claro (check)` o registra la duda en `observaciones_dudas`.

Nunca inventes un dato para completar una celda.

## 9. Modelo de datos interno

No uses una única tabla ancha como estructura interna. Separa la identidad estable del instrumento de sus distintas ediciones/convocatorias.

Crea al menos:

### `data/canonical/opportunities.csv`

Una fila por instrumento u oportunidad estable.

Campos sugeridos:

- `opportunity_id`
- `tipo_oportunidad` (`fondo`, `estancia`, `ambos`)
- `convocatoria`
- `programa`
- `institucion_financiante`
- `institucion_destino`
- `pais`
- `region`
- `idiomas_postulacion`
- `area_disciplinar`
- `objetivo`
- `alcance`
- `perfil_investigador_elegible`
- `etapa_carrera`
- `tipo_investigacion`
- `requisitos_contraparte`
- `rol_permitido_para_postulante`
- `frecuencia_apertura_llamado`
- `frecuencia_normalizada`
- `first_seen`
- `last_seen`
- `active_record`
- `legacy_source_id`

Usa IDs estables; no dependas del número de fila.

### `data/canonical/calls.csv`

Una fila por edición o convocatoria concreta.

Campos sugeridos:

- `call_id`
- `opportunity_id`
- `edicion`
- `fecha_apertura`
- `fecha_cierre`
- `fecha_apertura_texto`
- `fecha_cierre_texto`
- `monto_financiamiento_texto`
- `monto_min`
- `monto_max`
- `moneda`
- `requiere_cofinanciamiento`
- `gastos_financiables`
- `gastos_cubiertos`
- `duracion_proyecto`
- `duracion_estancia`
- `periodo_estancia`
- `elegibilidad_uchile`
- `estado_fuente`
- `estado_calculado`
- `observaciones_dudas`
- `first_seen`
- `last_verified`
- `review_required`

Las fechas normalizadas deben ser ISO `YYYY-MM-DD` cuando haya una fecha completa verificable. Conserva también el texto original cuando la fecha sea parcial, múltiple o ambigua.

El estado publicado debe derivarse determinísticamente de las fechas cuando sea posible, en vez de confiar ciegamente en un texto legacy como “Abierta”.

### `data/canonical/sources.csv`

Una fila por URL, no múltiples URLs concatenadas en una celda.

Campos:

- `source_id`
- `opportunity_id`
- `call_id` cuando corresponda
- `url`
- `source_role`
- `source_priority`
- `is_official`
- `domain`
- `last_checked`
- `http_status`
- `content_hash`
- `last_changed`
- `notes`

### `data/canonical/changes.csv`

Una fila por cambio detectado:

- `change_id`
- `run_id`
- `opportunity_id`
- `call_id`
- `field`
- `old_value`
- `new_value`
- `source_id`
- `detected_at`
- `auto_applied`
- `review_required`
- `reason`

### `data/canonical/runs.csv`

Registra cada ejecución:

- `run_id`
- `started_at`
- `finished_at`
- `mode`
- `sources_checked`
- `sources_changed`
- `candidates_found`
- `records_added`
- `records_updated`
- `review_items_created`
- `errors`
- `status`

### `data/canonical/review_queue.csv`

Para:

- nuevos candidatos con evidencia insuficiente;
- cambios críticos ambiguos;
- duplicados dudosos;
- pérdida de una fuente;
- discrepancias entre fuentes;
- registros legacy posiblemente fuera de alcance.

### `data/canonical/excluded_candidates.csv`

Guarda candidatos descartados y la razón, para evitar redescubrirlos indefinidamente.

## 10. Campos mínimos de la base publicada

Además del modelo interno, genera exportaciones simples pensadas para gestión.

### `data/published/fondos_investigacion.csv`

Debe contener como mínimo:

- `convocatoria`
- `programa`
- `institucion_financiante`
- `pais`
- `region`
- `idiomas`
- `area_disciplinar`
- `objetivo`
- `alcance`
- `perfil_investigador_elegible`
- `requiere_cofinanciamiento`
- `monto_financiamiento`
- `moneda`
- `gastos_financiables`
- `duracion_proyecto`
- `fecha_apertura`
- `fecha_cierre`
- `frecuencia_apertura_llamado`
- `enlaces`
- `elegibilidad_uchile`
- `observaciones_dudas`

Puedes añadir al final campos útiles como `etapa_carrera`, `tipo_investigacion`, `estado_actual`, `ultima_verificacion` e `id`, pero no elimines los mínimos.

### `data/published/estancias_investigacion.csv`

Debe contener como mínimo:

- `convocatoria`
- `programa`
- `institucion_financiante`
- `institucion_destino`
- `pais`
- `region`
- `perfil_investigador_elegible`
- `requisitos_idiomas`
- `requisitos_contraparte`
- `area_disciplinar`
- `objetivo`
- `alcance`
- `duracion_estancia`
- `periodo_estancia`
- `fecha_apertura`
- `fecha_cierre`
- `requiere_cofinanciamiento`
- `gastos_cubiertos`
- `frecuencia_apertura_llamado`
- `enlaces`
- `elegibilidad_uchile`
- `observaciones_dudas`

### Valores faltantes

Internamente usa `NA`/`null`.

Solo en las exportaciones de gestión transforma faltantes según corresponda a:

- `No encontrado`
- `No claro (check)`

No uses `"No encontrado"` como sustituto de `NA` en las tablas canónicas internas.

## 11. Tratamiento de la frecuencia

El término `Bianual` es ambiguo. No dependas de él para lógica.

Conserva el texto requerido en la exportación, pero crea `frecuencia_normalizada` con valores explícitos como:

- `anual`
- `dos_veces_al_ano`
- `cada_dos_anos`
- `permanente`
- `puntual`
- `irregular`
- `no_encontrado`
- `no_claro`

No transformes automáticamente dos cierres por año en “cada dos años”.

## 12. Migración de la base legacy

Crea `R/migrate_legacy.R` y/o `scripts/migrate_legacy.R`.

Mapeo inicial esperado:

- `instrumento` -> `convocatoria`
- `institucion_madre_o_programa_paraguas` -> `programa`
- `Origen_financiamiento` -> insumo inicial para `region`, pero **debe verificarse y no equivale a `pais`**
- `objetivo_y_alcance_breve` -> dividir cuidadosamente entre `objetivo` y `alcance`
- `fecha_convocatoria` -> intentar separar `fecha_apertura` y `fecha_cierre`, conservando siempre el texto legacy
- `duracion_financiamiento` -> `duracion_proyecto` para fondos o `duracion_estancia` si el registro es una estancia
- `elegibilidad_chile` + `elegibilidad_universidad_chilena` -> insumos para `elegibilidad_uchile`, pero no asumir equivalencia sin revisión
- `enlaces` -> dividir por ` | ` y normalizar a una fila por URL en `sources.csv`
- conservar `etapa_carrera`, `tipo_investigacion`, `rol_permitido_para_postulante` y `estado_actual` como información útil.

Además:

1. Conserva una copia tabular del contenido legacy sin transformar en `data/staging/legacy_grants.csv`.
2. Genera IDs estables.
3. Detecta duplicados exactos por combinación de nombre/institución y posibles duplicados por similitud de nombres/URLs.
4. **No elimines automáticamente duplicados** si contienen información distinta. Propón una reconciliación y conserva trazabilidad.
5. Clasifica cada registro legacy como `fondo`, `estancia`, `ambos`, `fuera_de_alcance` o `revisar`.
6. Revalida posteriormente estados, fechas y elegibilidad; la base legacy sirve como semilla, no como verdad vigente.
7. Produce `docs/migration_report.md` con los resultados y decisiones.

## 13. Deduplicación

Implementa deduplicación en capas:

1. coincidencia de URL canónica;
2. coincidencia exacta de institución + convocatoria normalizadas;
3. coincidencia por dominio + nombre normalizado;
4. similitud difusa de nombre como señal, nunca como criterio único de fusión.

Los registros recurrentes de un mismo instrumento en distintos años deben ser **una oportunidad con múltiples `calls`**, no duplicados.

## 14. Monitoreo de oportunidades conocidas

Crea un flujo que:

1. selecciona las fuentes que corresponde revisar;
2. descarga contenido cuando sea permitido;
3. calcula hash;
4. identifica fuentes nuevas/cambiadas;
5. extrae nuevamente solo lo necesario;
6. valida;
7. compara campo por campo;
8. crea entradas en `changes.csv`;
9. actualiza `last_verified`;
10. aplica cambios de alta confianza;
11. envía cambios ambiguos a `review_queue`.

No borres automáticamente una oportunidad porque una URL dé 404 o desaparezca. Marca la fuente como no disponible y busca una nueva página oficial antes de cambiar el estado.

Considera “campos críticos”:

- elegibilidad;
- fecha de apertura;
- fecha de cierre;
- monto;
- requisitos de contraparte;
- cofinanciamiento;
- estado/vigencia.

Un cambio crítico respaldado únicamente por una fuente secundaria debe requerir revisión.

## 15. Descubrimiento de nuevas oportunidades

Crea un módulo independiente.

Debe:

- ejecutar las consultas configuradas;
- guardar candidatos y fuentes;
- normalizar nombre e institución;
- comparar contra oportunidades existentes y exclusiones;
- buscar evidencia oficial;
- clasificar `fondo`/`estancia`/`ambos`;
- evaluar ajuste disciplinar;
- evaluar elegibilidad para UChile;
- extraer los campos del schema;
- asignar nivel de confianza;
- insertar automáticamente solo candidatos con evidencia oficial suficiente;
- mandar casos dudosos a revisión.

No permitas que un único resultado de agregador sea suficiente para incorporar automáticamente una oportunidad.

## 16. Overrides humanos

Crea:

- `config/manual_overrides.yml`
- `config/exclusions.yml`

Los `manual_overrides` deben aplicarse **después** de la extracción automática.

Un valor corregido manualmente no puede ser sobrescrito silenciosamente por una ejecución posterior. Si la web contradice un override, crea un item de revisión.

Documenta el formato con ejemplos.

## 17. Estado de las convocatorias

Usa una taxonomía interna clara, por ejemplo:

- `upcoming`
- `open`
- `closed`
- `rolling`
- `inactive`
- `unknown`

Cuando existan fechas completas, calcula el estado usando la fecha de ejecución y zona horaria `America/Santiago`.

En la exportación muestra etiquetas en español:

- `Próxima`
- `Abierta`
- `Cerrada`
- `Permanente`
- `No vigente`
- `No claro (check)`

Conserva separadamente cualquier estado textual declarado por la fuente.

## 18. Sitio Quarto

Crea un sitio estático, sobrio y profesional, pensado para equipos de gestión.

Como mínimo:

### Inicio

Mostrar:

- fecha/hora de última actualización;
- número total de oportunidades;
- número de fondos;
- número de estancias;
- número de convocatorias abiertas;
- número de próximos cierres.

### Fondos de investigación

Tabla cliente-side, buscable y filtrable.

Filtros especialmente útiles:

- estado;
- región/país;
- área disciplinar;
- etapa de carrera;
- financiador;
- elegibilidad UChile;
- rango aproximado de cierre.

### Estancias

Tabla equivalente con:

- institución de destino;
- país;
- duración;
- contraparte requerida;
- gastos cubiertos.

### Próximos cierres

Orden ascendente por fecha de cierre, excluyendo fechas no verificadas.

### Cambios recientes

Mostrar cambios detectados desde las últimas ejecuciones, con:

- oportunidad;
- campo;
- valor anterior;
- valor nuevo;
- fecha;
- fuente.

### Metodología

Explicar:

- criterios de inclusión;
- fuentes;
- significado de `(check)`;
- frecuencia de actualización;
- que las bases oficiales son siempre la referencia definitiva.

No publiques por defecto `review_queue`, `excluded_candidates` ni información de configuración interna.

Los enlaces a fuentes oficiales deben ser clickeables.

El sitio debe poder renderizarse localmente con un único comando documentado.

## 19. GitHub Actions

Crea dos workflows separados.

### A. `.github/workflows/update-data.yml`

Debe:

- permitir `workflow_dispatch`;
- ejecutar en horario programado;
- usar un minuto no redondo para reducir congestión;
- configurar R y `renv`;
- ejecutar tests básicos;
- ejecutar el pipeline en modo programado;
- validar outputs antes de persistirlos;
- hacer commit y push **solo si cambiaron archivos canónicos/publicados**;
- usar permisos mínimos necesarios;
- tomar `OPENAI_API_KEY` desde GitHub Secrets;
- no imprimir secretos en logs.

Diseña dos cadencias lógicas:

- monitoreo de oportunidades conocidas: aproximadamente dos veces por semana;
- descubrimiento amplio: aproximadamente una vez por semana.

Puedes resolverlo con un solo workflow y modos distintos según el día, o de otra forma simple y mantenible.

### B. `.github/workflows/publish-site.yml`

Debe:

- activarse por cambios relevantes en `main` y manualmente;
- configurar R/Quarto;
- renderizar el sitio;
- desplegar a GitHub Pages usando el método oficial vigente;
- no depender de que HTML generado esté versionado en `main`, salvo que exista una razón clara.

Consulta la documentación oficial vigente de GitHub Actions y Quarto antes de fijar las versiones de actions.

## 20. Estructura sugerida

Adáptala si el repositorio ya tiene una mejor estructura:

```text
.
├── AGENTS.md
├── README.md
├── .env.example
├── .gitignore
├── renv.lock
├── R/
│   ├── config.R
│   ├── ids.R
│   ├── legacy.R
│   ├── fetch.R
│   ├── openai_client.R
│   ├── extract.R
│   ├── validate.R
│   ├── deduplicate.R
│   ├── reconcile.R
│   ├── monitor.R
│   ├── discover.R
│   ├── changes.R
│   ├── export.R
│   └── site_helpers.R
├── scripts/
│   ├── migrate_legacy.R
│   ├── update.R
│   ├── qa.R
│   └── render_site.R
├── config/
│   ├── sources.yml
│   ├── discovery_queries.yml
│   ├── manual_overrides.yml
│   ├── exclusions.yml
│   └── schemas/
│       └── opportunity.schema.json
├── data/
│   ├── staging/
│   ├── canonical/
│   ├── published/
│   └── fixtures/
├── docs/
│   ├── initial_audit.md
│   ├── architecture.md
│   └── migration_report.md
├── site/
│   ├── _quarto.yml
│   ├── index.qmd
│   ├── fondos.qmd
│   ├── estancias.qmd
│   ├── proximos-cierres.qmd
│   ├── cambios.qmd
│   └── metodologia.qmd
├── tests/
│   └── testthat/
└── .github/
    └── workflows/
        ├── update-data.yml
        └── publish-site.yml
```

## 21. CLI y modos de ejecución

Quiero poder ejecutar algo equivalente a:

```bash
Rscript scripts/migrate_legacy.R
Rscript scripts/update.R --mode monitor --dry-run
Rscript scripts/update.R --mode discover --dry-run --limit 5
Rscript scripts/update.R --mode full
Rscript scripts/qa.R
quarto render site
```

Implementa:

- `--dry-run`: no altera tablas canónicas;
- `--limit`: limita candidatos/fuentes para pruebas;
- `--mode monitor|discover|full`;
- mensajes de log claros;
- código de salida distinto de cero para fallas críticas.

## 22. Seguridad, robustez y comportamiento ante errores

- Nunca borres datos canónicos porque falló una descarga.
- Haz actualizaciones de forma atómica: validar primero, reemplazar después.
- Si una fuente falla, conserva el dato anterior y registra el error.
- Usa timeouts y reintentos limitados.
- Respeta robots.txt, términos de uso y rate limits razonables.
- No intentes eludir autenticación, paywalls, captchas ni controles de acceso.
- No hagas scraping agresivo.
- Prefiere APIs, RSS y páginas oficiales estables cuando existan.
- Normaliza URLs para eliminar parámetros de tracking cuando sea seguro.
- No guardes secretos en Git.
- Nunca incluyas la API key en archivos, HTML o logs.
- El pipeline debe ser idempotente: correrlo dos veces sin cambios externos no debe crear duplicados ni falsos cambios.

## 23. Tests mínimos obligatorios

Usa `testthat`.

Incluye tests para:

1. lectura del archivo legacy;
2. mapeo de columnas;
3. separación de múltiples URLs;
4. generación estable de IDs;
5. normalización de fechas;
6. normalización de montos;
7. deduplicación exacta;
8. detección de posibles duplicados;
9. clasificación fondo/estancia;
10. derivación de estado por fecha;
11. una fixture donde cambia una fecha de cierre y se crea exactamente un cambio;
12. una fixture sin cambios y no se crea ningún cambio;
13. un 404 no elimina el registro;
14. un manual override no es sobrescrito;
15. un candidato claramente inelegible termina en exclusiones;
16. un candidato ambiguo termina en `review_queue`;
17. el pipeline repetido es idempotente;
18. las dos exportaciones contienen todos los campos mínimos;
19. el sitio Quarto renderiza correctamente.

Los tests no deben hacer llamadas reales a OpenAI ni depender de Internet.

## 24. QA y reportes

`scripts/qa.R` debe revisar al menos:

- IDs duplicados;
- URLs inválidas;
- claves foráneas rotas;
- fechas de cierre anteriores a apertura;
- moneda ausente cuando existe monto numérico;
- oportunidades publicadas sin fuente;
- oportunidades marcadas `Sí` en elegibilidad sin evidencia oficial suficiente;
- valores fuera de enums;
- oportunidades abiertas con fecha de cierre pasada;
- duplicados probables;
- campos mínimos faltantes.

Genera un resumen legible en consola y falla con código no cero solo ante errores que comprometan la integridad.

## 25. AGENTS.md

Como uno de los primeros archivos, crea un `AGENTS.md` conciso para que futuras sesiones de Codex mantengan las reglas del proyecto.

Debe incluir como mínimo:

- objetivo del repositorio;
- R-first;
- no modificar archivos legacy;
- no inventar datos;
- fuentes oficiales primero;
- no borrar ante fallas;
- manual overrides prevalecen;
- tests sin consumo de API;
- ejecutar QA y tests antes de considerar una tarea terminada;
- mantener compatibilidad con Quarto/GitHub Actions;
- documentar cambios de esquema.

## 26. README

El `README.md` debe permitir que otra persona entienda:

- qué hace el proyecto;
- arquitectura;
- cómo instalar dependencias;
- cómo configurar `.env`;
- cómo migrar la base;
- cómo correr un monitoreo de prueba;
- cómo hacer descubrimiento limitado;
- cómo renderizar el sitio;
- cómo funcionan overrides/exclusiones;
- cómo se configura GitHub Actions y GitHub Pages;
- qué archivos son canónicos y cuáles generados.

## 27. Criterios de término del MVP

No consideres el trabajo terminado hasta que:

1. la base legacy pueda migrarse sin modificar el original;
2. la migración produzca un informe de duplicados y calidad;
3. las tablas canónicas existan y validen;
4. haya fixtures para simular páginas/fuentes;
5. el monitoreo detecte cambios sobre fixtures;
6. el descubrimiento tenga una interfaz funcional y pueda probarse en modo mock;
7. exista integración real con OpenAI detrás de variables de entorno, pero los tests no la usen;
8. existan `manual_overrides` y exclusiones;
9. se generen las dos exportaciones de gestión;
10. el sitio Quarto renderice localmente;
11. los workflows de actualización y publicación estén creados;
12. todos los tests y QA pasen;
13. `README.md`, `AGENTS.md` y documentación técnica estén actualizados.

## 28. Orden de implementación

Trabaja en este orden:

1. inspección y auditoría del repositorio/inputs;
2. `AGENTS.md` y documentación de arquitectura;
3. scaffolding + `renv`;
4. esquema canónico;
5. migración legacy;
6. validación/deduplicación;
7. fixtures + tests;
8. monitoreo determinístico;
9. registro de cambios;
10. overrides y review queue;
11. descubrimiento en mock;
12. integración real con OpenAI;
13. exportaciones;
14. sitio Quarto;
15. GitHub Actions;
16. QA final.

No sacrifiques trazabilidad por velocidad.

## 29. Al finalizar tu primera pasada

Entrégame un resumen breve con:

- archivos creados/modificados;
- decisiones de arquitectura tomadas;
- resultados de la auditoría/migración;
- tests ejecutados y su resultado;
- comandos exactos que debo correr yo;
- variables/secrets que debo configurar;
- cualquier decisión que realmente necesite mi aprobación antes de continuar.

Si detectas que algún supuesto de este prompt contradice claramente los archivos de insumo, **prioriza los archivos**, documenta la discrepancia y explícame qué ajustaste.
