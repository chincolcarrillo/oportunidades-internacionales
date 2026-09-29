# Arquitectura de tres agentes — versión 2

## Qué se implementó

Tres roles operativos ejecutables, coordinados mediante archivos y GitHub Actions.
Descubrimiento usa búsqueda asistida por IA; vigilancia usa HTTP y hashes;
curaduría usa extracción estructurada y reglas R para decidir. La coordinación es
determinista: no se depende de tres chats abiertos ni de memoria de conversación.
Los contratos de docs/agents también permiten trabajar con cada rol en una sesión
interactiva de un asistente de programación.

Esto no instala tres asistentes capaces de reprogramarse sin supervisión. El rol de
vigilancia incluye instrucciones para mantenimiento interactivo del script; sus
ejecuciones programadas observan páginas y entregan evidencia. Un cambio de código
se prueba e integra por separado. Tampoco se implementa investigación autónoma
ilimitada de PDFs, fuentes inaccesibles o contradicciones: quedan trazadas.

## Flujo

1. Descubrimiento y vigilancia leen la misma revisión de la base, sin escribirla.
2. Cada productor entrega una cola JSON. Fallas HTTP también son observaciones.
3. Curaduría consume tanto las observaciones nuevas como las pendientes `retry`.
4. La huella de los datos impide aplicar una propuesta sobre una base diferente.
5. Se aplican sólo hechos con evidencia según reconcile/consider_candidate;
   overrides al final. Validación fallida descarta los cambios de esa propuesta.
6. Base, decisiones y vistas se guardan juntas mediante save_db().
7. GitHub ejecuta tests, QA y render antes de guardar cambios en main, si la
   propietaria activó AUTO_COMMIT_DATA. El job de escritura no recibe clave OpenAI.
8. Publish site sólo se ejecuta manualmente por DEPLOY_OWNER, sobre un SHA explícito
   perteneciente a main. No hay push ni workflow_run que disparen publicación.

## Contratos y esquema

Los siete CSV canónicos existentes conservan sus columnas. Se añade la tabla
`agent_decisions.csv`: proposal_id (clave), role, run_id, decided_at, status, reason,
attempts, evidence_hash. load_db inicializa una tabla vacía si el archivo no existe:
la migración es aditiva y no reinterpreta las 92 filas legacy.

Estados: applied, unchanged, excluded, review, retry, stale. `review` puede incluir
campos aplicados y otros bloqueados; changes.csv conserva el detalle por campo.
`retry` se reintenta en un ciclo posterior. Los demás estados no se reprocesan
automáticamente. `stale` requiere una observación nueva: la evidencia tiene un
máximo de 14 días y no puede reemplazar datos cambiados después de observarla.
Una nueva observación tiene otro proposal_id y no borra la historia anterior.

Propuestas v1: version, proposal_id, role, run_id, observed_at, url, source_id,
baseline, http_status, error, evidence_hash, text. baseline es SHA-256 de los datos
del instrumento/edición y URL, excluyendo marcas operativas y estado calculado.
El valor anterior de cada cambio aplicado sigue en changes.csv. El JSON guarda
el texto nuevo; no se afirma disponer de una captura anterior para fuentes legacy.
El hash de evidencia detecta corrupción accidental; no es una firma criptográfica.

Las observaciones de vigilancia añaden previous_hash y content_changed para señalar
el cambio de contenido. No confundir ese cambio con un cambio de fecha o monto:
curaduría determina los campos afectados y los registra en changes.csv.

La CLI anterior `update.R --mode monitor|discover` sigue disponible, pero sólo
produce propuestas. `--mode full` se retira para evitar escrituras implícitas.
Usar agent.R con roles separados. Las funciones legacy monitor/discover se conservan
para pruebas y compatibilidad interna; los workflows de producción no las invocan.

## Evidencia, concurrencia y presupuesto

data/proposals conserva observaciones completas versionadas. data/agent-evidence
conserva extracciones por URL+hash; una extracción ya guardada se puede reutilizar.
Las respuestas API crudas continúan en staging ignorado: no son el archivo durable.
Los artefactos de GitHub duran 30 días; después de AUTO_COMMIT_DATA, el respaldo
duradero es Git. Con AUTO_COMMIT_DATA=false, descargar el artefacto si se necesita
conservar el ensayo. Ni propuestas ni ledger ni extracciones se copian al sitio.

Todos los lotes usan concurrency agents-data. Curaduría es un solo escritor.
El job de persistencia compara HEAD de main con el SHA de origen: si alguien editó
main durante la ejecución, falla sin sobrescribirlo. Nunca se usa force push ni
rebase automático. Localmente no ejecutar escritores a la vez.

AGENT_MAX_CALLS limita solicitudes API por proceso, por defecto 3. Descubrimiento
y curaduría tienen límites independientes: full puede realizar hasta 6 solicitudes
con ese valor. Las herramientas de búsqueda y los tokens pueden tener cargos
adicionales: esto no es un tope monetario. Configurar presupuesto y alertas de API.
No se han activado búsquedas pagadas como parte de esta migración.

## Permisos y límites de confianza

Los jobs de los tres roles tienen contents:read. Sólo persist tiene contents:write
y sólo añade rutas de datos. GitHub no ofrece con ese token una restricción por
carpeta: el límite se implementa en el workflow confiable. No dar a los asistentes
credenciales personales de administración o publicación. El código R y YAML es
código de confianza del repositorio; debe revisarse antes de integrarlo.

La publicación comprueba github.actor y github.triggering_actor, para que una
reejecución por otra persona tampoco despliegue. DEPLOY_OWNER debe ser una cuenta
personal, no el nombre de una organización. Proteger el entorno github-pages con
esa persona como revisora cuando el plan lo permita; permitir autoaprobación si
ella inicia el flujo. Sólo la propietaria debe administrar configuración/workflows.

El auto-commit requiere que las reglas de main permitan al token guardar datos.
Si se exigen PRs/revisiones sin excepción, persist fallará; no desactivar protecciones
a ciegas. Adoptar integración por PR con identidad autorizada es una extensión
pendiente. Sin auto-commit, la ejecución entrega una versión descargable.

Referencias oficiales consultadas el 2026-09-29:

- [Permisos de GITHUB_TOKEN](https://docs.github.com/en/actions/tutorials/authenticate-with-github_token)
- [Variables y actores de reejecución](https://docs.github.com/en/actions/reference/workflows-and-actions/variables)
- [Entornos y aprobación de despliegues](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments)
