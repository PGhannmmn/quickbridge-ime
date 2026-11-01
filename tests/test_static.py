from pathlib import Path
import hashlib, json, re
root=Path(__file__).resolve().parents[1]
manifest=json.loads((root/'SHA256SUMS.json').read_text(encoding='utf-8'))
checks=[]
def ck(desc,ok):
    assert ok,desc
    checks.append(desc)
for name,h in manifest.items():
    p=root/name
    ck('hash: '+name,p.is_file() and hashlib.sha256(p.read_bytes()).hexdigest().upper()==h)
schema=(root/'quickbridge.schema.yaml').read_text(encoding='utf-8')
proc=(root/'lua/quickbridge_processor_v29.lua').read_text(encoding='utf-8')
filter=(root/'lua/quickbridge_openvanilla_filter_v21.lua').read_text(encoding='utf-8')
inst=(root/'tools/Install-QuickBridge.ps1').read_text(encoding='utf-8-sig')
ck('public version', 'version: "1.0.1"' in schema)
ck('public scheme id', 'schema_id: quickbridge' in schema)
ck('native predictor', 'predict_translator' in schema)
ck('guard linked','lua_processor@*quickbridge_prediction_guard_v21' in schema)
ck('filter linked','lua_filter@*quickbridge_openvanilla_filter_v21' in schema)
ck('processor linked','lua_processor@*quickbridge_processor_v29' in schema)
ck('no filter remark','〔OpenVanilla 歷史序〕' not in filter)
ck('original quick dictionary','dictionary: qb_quick' in schema)
ck('nine slots','page_size: 9' in schema)
ck('numpad digits supported','0xffb0' in proc and '0xffb9' in proc)
ck('numpad operators supported',all(x in proc for x in ('0xffaa','0xffab','0xffad','0xffae','0xffaf')))
ck('refuse overwrite','FileMode]::CreateNew' in inst and '[IO.File]::Copy' in inst)
ck('no registry writes', all(s not in inst for s in ['Set-ItemProperty','New-ItemProperty','reg.exe']))
ck('no global patch writes',not re.search(r'(Out-File|Set-Content|Add-Content).*?(default\.custom|weasel\.custom)',inst,re.I|re.S))
ck('fixed OpenVanilla blob','cff9bbba57f7b5858066c8b52ccf66f4d21717c2' in inst)
ck('fixed predictor blob','e0a0e92bff6690a7f630a6fd5f09b674d83526b0' in inst)
ck('MIT upstream notice',(root/'licenses/RIME_MS_QUICK_LICENSE.txt').is_file())
for p in root.rglob('*'):
 if p.is_file() and p.suffix in ('.md','.ps1','.yaml','.lua','.json','.txt'):
    s=p.read_text(encoding='utf-8-sig')
    ck('no private data '+str(p.relative_to(root)),not re.search(r'C:\\Users\\andre|qqqa16521|DESKTOP-VKH9OFS|andr[eE]@',s))
print('PUBLIC STATIC PASS:',len(checks),'checks')
