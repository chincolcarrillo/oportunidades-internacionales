"""Read-only input inspection; runtime pipeline remains R-first."""
import collections, hashlib, json, re
from pathlib import Path
import openpyxl
from pypdf import PdfReader

root = Path(__file__).resolve().parents[1]
out = root / 'docs'
out.mkdir(exist_ok=True)
wb = openpyxl.load_workbook(root/'input/base_grants_investigacion_Chile.xlsm', read_only=True, data_only=True)
audit = {}
for sheet in wb:
    values = list(sheet.values)
    width = max(i+1 for row in values for i,v in enumerate(row) if v is not None)
    headers = [v or f'unnamed_{i+1}' for i,v in enumerate(values[0][:width])]
    rows = [dict(zip(headers, row[:width])) for row in values[1:] if any(v is not None for v in row)]
    audit[sheet.title] = {'rows':len(rows),'columns':width,'headers':headers,'records':rows,
        'vocabularies':{k:dict(collections.Counter(str(r.get(k)) for r in rows)) for k in ['Origen_financiamiento','estado_actual','frecuencia_apertura_llamado','requiere_cofinanciamiento','moneda']}}
(out/'input_inventory.json').write_text(json.dumps(audit, ensure_ascii=False, indent=2, default=str),encoding='utf-8')
pdf = next((root/'input').glob('*.pdf'))
(out/'minimum_requirements.txt').write_text('\n\n'.join(re.sub(r'\s+',' ',p.extract_text()) for p in PdfReader(pdf).pages),encoding='utf-8')
(out/'input_checksums.json').write_text(json.dumps({p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in (root/'input').iterdir() if p.suffix in ['.xlsm','.pdf']},indent=2),encoding='utf-8')
for name,a in audit.items():
    print(name, a['rows'], a['columns'])
    print(json.dumps(a['vocabularies'],ensure_ascii=True))
    for i,r in enumerate(a['records']):
        print(i+2, json.dumps([r.get('instrumento'),r.get('institucion_financiante')],ensure_ascii=True))
