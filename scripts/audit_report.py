import collections, csv, hashlib, json, unicodedata
from pathlib import Path
root=Path(__file__).resolve().parents[1]
def norm(s):
    return ''.join(c for c in unicodedata.normalize('NFKD',str(s)).lower() if c.isalnum() or c.isspace()).strip()
audit=json.loads((root/'docs/input_inventory.json').read_text(encoding='utf-8'))['grants_investigacion']
rows=audit['records']
groups=collections.defaultdict(list)
for i,r in enumerate(rows,2): groups[(norm(r['instrumento']),norm(r['institucion_financiante']))].append(i)
same=[(k,v) for k,v in groups.items() if len(v)>1]
full=collections.Counter(json.dumps(r,sort_keys=True,ensure_ascii=False) for r in rows)
with (root/'data/staging/legacy_classification.csv').open(encoding='utf-8',newline='') as f: classified=list(csv.DictReader(f))
counts=collections.Counter(r['classification'] for r in classified)
text=['# Auditoría inicial','', 'Fecha: 2026-09-24. Inspección completa del Excel y del PDF de mínimos; originales tratados como solo lectura.', '',
'## Estructura', '',
'Una hoja `grants_investigacion`, 92 registros y 22 columnas con contenido. El rango físico observado incluye cinco columnas vacías adicionales, descartadas de la tabla de datos. No se encontraron otras hojas. Las carpetas docs y script estaban vacías; no existía repositorio Git inicializado.', '',
'## Campos existentes', '', *['- `'+h+'`' for h in audit['headers']], '',
'## Mínimos ausentes o incompletos', '',
'No existen país, idiomas de postulación, institución destino, requisitos de contraparte, periodo de estancia ni fechas separadas de apertura/cierre. Objetivo y alcance están juntos. Duración no distingue proyecto y estancia. La elegibilidad para Chile/universidad chilena no verifica directamente UChile. El monto es texto, con moneda a veces ambigua. Los gastos son de investigación, sin un campo específico de gastos cubiertos de estancia.', '',
'Mapeos directos: instrumento → convocatoria; institución madre → programa; origen → región provisional. No equivale a país. Campos a conservar aunque no sean mínimos: etapa de carrera, tipo de investigación, rol permitido, estado textual histórico, observaciones y ambos textos de elegibilidad.', '',
'## Duplicados', '',
f'Duplicados de fila completa: {sum(n-1 for n in full.values())}. Grupos con coincidencia exacta de instrumento + institución normalizados: {len(same)}; {sum(len(v)-1 for _,v in same)} versiones adicionales. Las filas se cuentan con cabecera Excel en fila 1.', '']
for (name,inst),indices in same: text.append(f'- {name} ({inst}): filas {", ".join(map(str,indices))}.')
text += ['', 'Posibles duplicados que requieren reconciliación: Spencer Small/Large en filas 18–19 y 65–66; Jacobs CIFAR en filas 10 y 72; instrumentos National Geographic generales, áreas y niveles en filas 28–29 y 63–64. Compartir dominio o URL de programa no prueba identidad: puede representar modalidades distintas. El reporte tabular registra candidatos adicionales por URL/nombre.', '',
'## Vocabularios e inconsistencias', '',
'- 18 estados legacy Abierta; 21 Cerrada; 34 Recurrente. Ninguna etiqueta se toma como estado vigente sin fecha comprobada.',
'- Bianual aparece en 9 registros y Bianual / Trienal en 1. Se marca frecuencia no_claro. Las combinaciones anual/permanente y las etiquetas con check también requieren revisión.',
'- Moneda contiene USD (check), CHF (check), BRL / CLP referencial y Variable; No encontrado. Solo códigos ISO exactos se trasladan al campo canónico de moneda.',
'- No encontrado aparece como texto; se transforma a NA interno. No aplica en programa se resuelve repitiendo convocatoria, de acuerdo con el PDF.',
'- Origen_financiamiento agrupa por continentes y organismos sin adscripción. No contiene país.',
'- Fechas combinan cierre, reunión de comité, rondas, última convocatoria y observaciones. No se extrae una fecha aislada sin identificar su significado.', '',
'## Alcance preliminar', '',
*['- '+k+': '+str(v)+' registros legacy.' for k,v in sorted(counts.items())], '',
'La clasificación es una heurística conservadora, pendiente de evidencia. Casos especialmente dudosos: Klaus J. Jacobs Research Prize (premio), Publication Subsidy Scheme (subsidio de publicación), Grand Challenges/Grant Opportunities y Convocatorias de investigación CLACSO (páginas paraguas). Fellowships sin evidencia de residencia no se convierten automáticamente en estancia. La convocatoria Uruguay–México y el anexo ANII Uruguay requieren comprobar participación chilena antes de afirmar elegibilidad.', '',
'Todos los registros se preservan en staging y canónico; los dudosos quedan inactivos y en revisión. Ninguno se descarta automáticamente durante migración por una interpretación inferida.', '',
'## Contraste con PDF', '',
'El PDF confirma el universo, los mínimos y la unidad por instrumento específico. Aclara que, si programa no aplica, debe repetirse convocatoria. No se detectaron contradicciones sustantivas con el prompt. El PDF permite la etiqueta Bianual en gestión, pero el modelo interno la conserva como ambigua. La normalización más estricta del prompt evita asignar periodicidad sin evidencia.', '',
'## Integridad', '',
'Los hashes SHA-256 iniciales figuran en input_checksums.json. El test de migración comprueba que el Excel no cambia. La auditoría auxiliar input_inventory.json conserva todos los valores inspeccionados; el pipeline operativo lee directamente el XLSM mediante readxl.']
(root/'docs/initial_audit.md').write_text('\n'.join(text)+'\n',encoding='utf-8')
print(json.dumps({'classification':dict(counts),'exact_groups':same,'full_duplicate_rows':sum(n-1 for n in full.values())},ensure_ascii=True))
