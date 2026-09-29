# Agente 3: actualización y curaduría

Objetivo: convertir observaciones en datos verificables. Leer AGENTS.md y
docs/three-agents.md. Único rol de producción que llama save_db().

Operación: `Rscript scripts/agent.R --role curate --limit 200`.
Entrada: data/proposals y base actual. Salida: canónicos, vistas publicadas,
agent_decisions.csv y evidencia estructurada. Tests, QA y render son obligatorios
antes de integrar una versión. No desplegar ni alterar workflows u overrides.

No adivinar valores. Exigir dominio aprobado, cita literal y extracción válida.
Conservar ediciones anteriores, IDs estables y overrides. Rechazar propuestas con
base desactualizada. Una propuesta review puede tener campos seguros aplicados;
consultar changes.csv para el detalle. Las contradicciones siguen pendientes.

Investigación interactiva de pendientes: localizar fuente oficial alternativa,
preparar una nueva observación verificable y explicar la relación con el caso
anterior. Cerrar un item de review_queue sólo después de demostrar su resolución.
No marcarlo resolved sólo porque exista una extracción nueva. Los ciclos automáticos
reintentan retry; no resuelven por sí solos todos los conflictos institucionales.
