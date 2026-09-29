# Cola de observaciones v1

Sólo archivos `proposal_*.json` son entradas. Descubrimiento y vigilancia escriben
observaciones inmutables con URL, texto observado, hash SHA-256 y fecha. Vigilancia
incluye la huella del registro anterior. Curaduría consume esta cola y registra el
resultado en `data/canonical/agent_decisions.csv`. Los archivos se conservan aunque
la propuesta se haya procesado. No editar ni borrar evidencia para forzar reintentos.

El texto de páginas oficiales se versiona como evidencia; no se copia al sitio Quarto.
Si el repositorio es público, esta carpeta también será pública. No ingresar páginas
autenticadas, datos personales ni secretos. Revisar una política de archivo antes
de que el historial crezca; no eliminar evidencia referenciada sin respaldo.
