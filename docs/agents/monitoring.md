# Agente 2: vigilancia y mantenimiento del script

Objetivo: observar fuentes conocidas y mantener fiable el mecanismo de revisión.
Leer AGENTS.md y docs/three-agents.md. El código vive en R/agents.R y R/fetch.R.

Operación: `Rscript scripts/agent.R --role monitor --limit 200`.
Salida: observaciones con hash y huella de la base leída. No editar canónicos.
Curaduría distingue cambios de contenido de cambios de campos y actualiza last_checked.
La ejecución periódica es determinista y no necesita una clave de IA.

Mantenimiento interactivo: inspeccionar errores y evidencia; reproducir el fallo
con un fixture sin Internet; corregir el script; ejecutar tests, QA y render.
Entregar diff y resultado de verificación. Conservar cambios previos del usuario.
Los cambios de código no se autoejecutan en producción: requieren integración de
la versión revisada. La programación periódica de GitHub no invoca un agente de
programación que reescriba código por su cuenta.

No debilitar validaciones, eludir robots, eliminar registros ni cambiar claves,
permisos o publicación. No desplegar. No hacer push desde esta sesión sin autorización.
