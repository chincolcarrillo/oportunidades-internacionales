# Tu primera puesta en marcha

## 1. Entender qué controlarás

GitHub guarda los archivos del proyecto. GitHub Actions ejecuta tareas programadas
en un equipo temporal. Un workflow es la receta de una tarea; un job es una etapa.
Un commit identifica una versión completa del proyecto. Deploy significa publicar
una versión en el sitio web. Guardar datos en GitHub y publicar son pasos separados.

Los tres roles ya tienen comandos y contratos en docs/agents. No necesitas abrir
tres chats para que funcione el ciclo programado. La búsqueda y la extracción usan
IA; la vigilancia web usa un script R. Para corregir ese script puedes encargarle
el trabajo a un asistente siguiendo docs/agents/monitoring.md: no se autorreprograma.

Tu rutina final será revisar el resumen y decidir cuándo publicar. Las dudas sin
evidencia quedan pendientes: no estás obligada a resolver todas para publicar los
registros que sí están respaldados.

## 2. Subir esta versión una sola vez

El remoto local apunta a:
[chincolcarrillo/oportunidades-internacionales](https://github.com/chincolcarrillo/oportunidades-internacionales).
Esta implementación no hizo commit ni push ni cambió ajustes de GitHub.

Si ya guardaste el commit «Cambio de enfoque», no necesitas repetirlo: revisa y
sube sólo los ajustes finales pendientes. La comprobación consolidada se ejecuta
con `Rscript scripts/verify.R` y genera docs/verification-agents.md.

Si usas GitHub Desktop:

1. Abre File > Add local repository y elige la carpeta de este proyecto.
2. Revisa Changes. Hay cambios anteriores a esta migración: no descartarlos; revisar
   qué incluir en el commit. No incluir .env, claves, .tools o la biblioteca renv.
3. Incluye R/agents.R, scripts/agent.R, scripts/demo_agents.R, scripts/update.R,
   R/config.R, R/validate.R, tests/testthat/test-agents.R y test-agent-workflows.R,
   los tres workflows, las carpetas docs/agents, la documentación actualizada,
   los README de data/proposals y data/agent-evidence y agent_decisions.csv.
4. Escribe un mensaje como «Separar descubrimiento, vigilancia y curaduría» y crea
   el commit. Revisa que la rama de destino sea main; si estás en otra, integra
   primero sus cambios mediante el flujo habitual de tu repositorio.
5. Pulsa Push origin. Esto sube archivos; esta versión no publica el sitio al hacer push.

No necesitas ejecutar comandos Git si prefieres que te acompañen en este paso.
No uses «discard all changes» para limpiar la carpeta.

## 3. Ejecutar una prueba sin IA pagada

1. En el repositorio web abre Actions.
2. Selecciona **Checks (offline)**. Puede haberse iniciado con el push.
3. Si no hay ejecución, pulsa Run workflow, elige main y confirma.
4. Espera a que termine en verde. Ejecuta tests con fixtures, una demostración de
   los tres roles, QA y render de las seis páginas.
5. Abre la ejecución. En Artifacts puedes descargar **site-preview** y abrir
   index.html después de descomprimir el ZIP completo.

«Offline» significa que las pruebas no consultan páginas ni llaman a la API.
GitHub sí descarga herramientas y dependencias. Sus minutos de ejecución están
sujetos al plan de GitHub. No necesitas clave OpenAI para esta comprobación.

## 4. Configurar credenciales y variables

En Settings > Secrets and variables > Actions encontrarás dos pestañas:
Secrets para contraseñas y Variables para opciones no secretas.

En **Secrets**, crea OPENAI_API_KEY con tu clave de API. Nunca la pegues en un CSV,
un archivo versionado o un chat. No hace falta un token personal de GitHub:
los workflows usan el GITHUB_TOKEN temporal del repositorio.

En **Variables**, crea:

| Nombre | Valor inicial | Para qué sirve |
|---|---|---|
| OPENAI_MODEL | Identificador del modelo disponible en tu cuenta | Debe admitir Responses, búsqueda web y salida estructurada, como requiere el cliente existente. |
| AGENT_MAX_CALLS | 3 | Máximo de solicitudes por proceso. |
| ENABLE_AUTOMATION | false | Mantiene apagado el calendario; permite ensayos manuales. |
| AUTO_COMMIT_DATA | false | El ensayo entrega artefactos, sin guardar datos en main. |
| ENABLE_PAGES | false | Mantiene apagada la publicación. |
| DEPLOY_OWNER | chincolcarrillo | Usuario personal de GitHub autorizado a publicar; cambia si tu usuario es otro. |

Configura también presupuesto y alertas en la cuenta de API. Tres solicitudes no
equivalen a tres unidades monetarias: una búsqueda usa herramientas y tokens.
En modo full hay dos procesos con API, con hasta 6 solicitudes entre ambos si
AGENT_MAX_CALLS=3. La vigilancia por sí sola no usa IA, pero su curaduría sí puede.

## 5. Hacer un primer ensayo real y pequeño

1. En Actions abre **Run three agents** > Run workflow.
2. Elige main, mode=monitor, limit=3 y curate_limit=3.
3. Este paso sí puede consumir API; ejecútalo después de configurar el presupuesto.
4. Observa los jobs: planificación, descubrimiento, vigilancia, curaduría. El rol
   que no corresponde al modo elegido termina sin consultar fuentes.
5. Revisa el resumen de curaduría y descarga **validated-data** y **site-preview**.
6. En validated-data encontrarás canonical/agent_decisions.csv y changes.csv.
   Compara old_value y new_value; source_id lleva a sources.csv. Las propuestas
   tienen el texto observado y agent-evidence tiene la extracción estructurada.

Con AUTO_COMMIT_DATA=false, **no se cambia main ni el sitio**. Los artefactos duran
30 días. Si deseas conservar ese ensayo, descárgalos antes de que caduquen.
El resumen puede indicar review, stale o retry aunque la ejecución técnica sea verde.
Eso significa que no se resolvieron todos los datos; no equivale a una verificación
completa del catálogo. Las 92 filas legacy todavía necesitan revisión web.

Después puedes ensayar mode=discover con limit=2. Los dominios fuera de
config/sources.yml quedan pendientes: la IA no los aprueba sola.

## 6. Activar el guardado y luego el calendario

Cuando el ensayo sea satisfactorio, cambia **AUTO_COMMIT_DATA=true**. Esto autoriza
al workflow a guardar únicamente datos y evidencia, después de tests, QA y render.
Ejecuta otro lote pequeño manualmente y verifica que **Guardar datos validados**
termine en verde. El resumen de ese job muestra el commit que podrás publicar.

Si GitHub rechaza el push por permisos o protección de main, detente y revisa las
reglas. El workflow pide contents:write sólo en esa etapa. No necesita permisos
administrativos. Si main exige PRs sin excepción, esta implementación no elude la
regla: deja AUTO_COMMIT_DATA=false hasta adaptar la integración por PR.

Cuando funcione el guardado, cambia **ENABLE_AUTOMATION=true**. Queda programado:

- Vigilancia: martes y viernes, 10:17 UTC, hasta 200 fuentes elegibles por ciclo.
- Descubrimiento: domingo, 10:43 UTC, hasta 5 candidatos.
- Curaduría: después de cada lote, con el límite API configurado.

GitHub puede demorar tareas programadas. UTC no cambia con el horario de verano
chileno. No es necesario convertir el horario para que funcione.

## 7. Configurar tu publicación exclusiva

1. Ve a Settings > Pages y selecciona **GitHub Actions** como Source.
2. En Settings > Environments abre o crea **github-pages**.
3. Si tu plan lo permite, establece tu cuenta como required reviewer y restringe
   despliegues a main. Permite autoaprobación: tú iniciarás y aprobarás el despliegue.
4. Comprueba que DEPLOY_OWNER coincide exactamente con tu usuario personal.
5. Cambia **ENABLE_PAGES=true**. Esto habilita el botón operativo; no publica solo.

La protección con revisora depende del plan y de si el repositorio es público o
privado. Independientemente de esa opción, el workflow exige tu usuario al iniciar
y al reejecutar, y nunca se dispara por actualizaciones de datos.

## 8. Publicar una versión

1. Revisa el resumen y preview de la ejecución que deseas publicar.
2. Copia el SHA completo del job Guardar datos validados; son 40 caracteres. También
   puedes copiar el identificador completo desde el commit en GitHub.
3. Abre Actions > **Publish site** > Run workflow.
4. Selecciona la rama **main** y pega ese SHA en commit_sha.
5. Ejecuta. GitHub vuelve a correr tests, QA y render sobre esa versión concreta.
6. Si configuraste aprobación del entorno, aprueba el despliegue pendiente.
7. Abre la URL entregada por el job Deploy y comprueba fondos, estancias y cierres.

Las actualizaciones posteriores no cambian el sitio hasta que repitas este paso.
Para recuperar una versión anterior puedes publicar su SHA, siempre que pertenezca
a main y pase los controles actuales. Una versión antigua puede requerir actualizar
sus estados de fechas para pasar QA: no se garantiza que todo commit histórico sea
publicable indefinidamente.

## 9. Rutina y problemas habituales

- Una vez por semana: mira el resumen, revisa cambios importantes y publica si quieres.
- retry: falló extracción o faltó presupuesto. Puedes ejecutar mode=curate sin
  repetir búsquedas. No subas el presupuesto sin revisar el motivo.
- stale: base cambiada o evidencia mayor a 14 días. Ejecuta una nueva vigilancia;
  si necesitas observar antes del intervalo mínimo, usa el comando local con --force.
- review: datos conservados o aplicación parcial. Requiere evidencia adicional;
  el agente de curaduría puede ayudarte a investigarlo con su contrato.
- Error HTTP: no elimina oportunidades; revisar una fuente oficial alternativa.
- Fallo de guardado por otro commit en main: volver a ejecutar el lote sobre la
  versión actual. No hacer force push.
- Fallo de código o parser: pedir al asistente que siga docs/agents/monitoring.md,
  reproduzca con fixture, corrija y entregue tests, QA y render.
- Para pausar: ENABLE_AUTOMATION=false. Para impedir guardado: AUTO_COMMIT_DATA=false.
  Para impedir publicación: ENABLE_PAGES=false.

## Comandos locales equivalentes

Desde la raíz del proyecto, con R y Quarto instalados y renv restaurado:

```sh
Rscript scripts/demo_agents.R
Rscript scripts/agent.R --role monitor --mock --dry-run --limit 3
Rscript scripts/agent.R --role discover --mock --dry-run --limit 2
```

Los siguientes son reales, pueden consumir API y guardan propuestas/datos:

```sh
Rscript scripts/agent.R --role monitor --limit 3
Rscript scripts/agent.R --role discover --limit 2
Rscript scripts/agent.R --role curate --limit 5
Rscript scripts/test.R
Rscript scripts/qa.R
Rscript scripts/render_site.R
```

Sólo curate escribe la base. --dry-run no persiste pero puede consumir API cuando
no se acompaña de --mock. No ejecutes dos curadores locales simultáneamente.

Referencias: [ejecuciones manuales](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow),
[entornos y revisores](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments).
