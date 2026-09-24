# Arquitectura del MVP

## Flujo y decisiones

R realiza lectura xlsm con readxl, normalización, HTTP, comparación, validación y exportación. Quarto y DT producen HTML estático con búsqueda y filtros en navegador. No hay servidor de aplicación ni base de datos externa. Python se usó únicamente para la auditoría inicial independiente del Excel/PDF.

La identidad estable es `opportunities`; las ediciones son `calls`. En la migración, las versiones legacy sin edición comprobada reciben identificadores provisionales diferentes. No se inventa el año de una edición a partir de fechas narrativas. Un nombre y financiador exactamente normalizados comparten instrumento; los demás candidatos similares van a revisión. Antes de incorporar nuevas ediciones, el descubrimiento compara nombre, institución, URL y dominio. La similitud difusa nunca autoriza fusión.

Los IDs usan SHA-256 truncado a 80 bits y claves de contenido, no números de fila. La fila original figura solamente en el mapa de trazabilidad. Modificar posteriormente una etiqueta no recalcula su ID persistido.

## Evidencia y cambios

Primero HTTP, respetando robots.txt, bloqueos configurados, 2 segundos entre solicitudes, timeout de 30 segundos y 2 intentos. Los redirects se revisan en lugar de seguirse sin comprobar el nuevo destino. PDFs y páginas que requieren JavaScript pasan a revisión para buscar una alternativa oficial. No se eluden controles.

Se conservan hash observado y hash extraído por separado. Una extracción fallida no bloquea el reintento. Un hash ya extraído no consume IA otra vez. Las fuentes compartidas reutilizan HTTP dentro de cada ejecución. Las páginas, respuestas API y candidatos se archivan localmente en `data/staging/evidence`; las citas que justifican elegibilidad/cierre y las propuestas ambiguas se conservan en CSV. Este archivo de evidencia está excluido de Git; respaldarlo si se necesita auditoría de texto completo entre ejecuciones de CI.

Las fuentes oficiales requieren un dominio aprobado en `config/sources.yml`. La IA no puede promover un dominio a oficial. Toda actualización automática requiere cita literal presente en el texto, URL correspondiente, dominio aprobado y extracción de alta confianza. Los campos desconocidos permanecen NA. Se compara campo por campo y se registra cada transición, incluyendo propuestas que requieren revisión. Una identidad de instrumento diferente pasa a revisión; una edición explícitamente nueva se procesa sin sobrescribir la anterior.

Los overrides se aplican al final y se registran como cambios. Una contradicción automática crea revisión, incluso si la fuente es oficial. La modificación de elegibilidad a Sí requiere fuente oficial y cita también para overrides. Un error HTTP no elimina datos. Los candidatos claramente inelegibles se excluyen; los existentes inelegibles se conservan internamente y se ocultan del catálogo.

## Persistencia y concurrencia

Los CSV se validan en memoria antes de escribir. `save_db()` toma un bloqueo, escribe una generación temporal, respalda directorios previos y reemplaza mediante rename. Ante error ordinario revierte ambos directorios. Una interrupción abrupta del proceso durante los renames puede dejar `.previous`, `.transaction` o `.lock`: detener ejecuciones y recuperar la generación anterior antes de continuar. Este MVP no afirma atomicidad transaccional de múltiples directorios ante corte de energía. La concurrencia del workflow evita escritores simultáneos en CI; ejecutar solo un escritor local a la vez.

`--dry-run` no altera canónicos ni publicados, pero puede guardar evidencia y, si no usa `--mock`, consumir API. Mock exige dry-run para impedir contaminación del catálogo.

## OpenAI y presupuesto

Se utiliza Responses API: búsqueda `web_search` con `web_search_call.action.sources`, seguida de extracción `text.format` con JSON Schema estricto. Se guardan fuentes y respuestas. La extracción adicional se valida con AJV/jsonvalidate. Modelo centralizado en `OPENAI_MODEL`; clave en `OPENAI_API_KEY`. `OPENAI_MAX_CALLS` limita solicitudes por proceso (10 predeterminadas), no gasto monetario; además establecer presupuesto en la cuenta API. No hay reintentos pagados automáticos. El límite de candidatos no equivale al número de consultas. Las familias rotan por semana para evitar que un presupuesto limitado cubra siempre las primeras. Los candidatos fuera de dominios aprobados pasan a revisión.

Documentación consultada el 2026-09-24:

- https://developers.openai.com/api/docs/guides/tools-web-search
- https://developers.openai.com/api/docs/guides/structured-outputs
- https://quarto.org/docs/publishing/github-pages.html
- https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages
- https://github.com/actions/checkout/releases
- https://github.com/r-lib/actions/tree/v2/setup-renv

## Esquema v1

Las columnas se definen en `R/config.R`. Adiciones frente al prompt: `sources.extracted_hash` permite reintentos; `calls.evidence_source_id`, `eligibility_evidence` y `closing_evidence` impiden marcar Sí o publicar próximos cierres sin evidencia. `tipo_oportunidad` es NA y `active_record=FALSE` para legacy dudoso. La revisión contiene ID determinístico, motivo, detalle, fecha y estado.

Las exportaciones incluyen todos los mínimos. El programa repite convocatoria cuando el legacy dice No aplica, como indica el PDF. País y región no se confunden; región legacy es provisional. Objetivo conserva el texto combinado y alcance queda NA hasta verificar. No se asignan monto numérico o fecha normalizada desde textos mixtos. Frecuencia Bianual es `no_claro`.

## Límites operativos

El primer catálogo es una migración, no una verificación web de las 92 filas. La revisión humana de identidad, edición y alcance sigue siendo necesaria. La lista inicial de dominios oficiales es deliberadamente acotada y extensible. No se automatiza resolución de captchas, PDFs, portales dinámicos ni fusión de duplicados dudosos. La integración API está implementada pero no se prueba con llamadas facturables en los tests.
