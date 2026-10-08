"""Generate an AltSource only from a validated, version-matching IPA."""
import argparse,copy,json,plistlib,zipfile,re
from pathlib import Path

def generate_source(previous: dict, ipa: Path, version: str, date: str, download_url: str, icon_url: str) -> dict:
    if not re.fullmatch(r'\d+\.\d+\.\d+',version):raise ValueError('Version must be MAJOR.MINOR.PATCH')
    if not all(u.startswith('https://') for u in [download_url,icon_url]):raise ValueError('HTTPS required')
    try:
        with zipfile.ZipFile(ipa) as z:
            info=plistlib.loads(z.read('Payload/Livecript.app/Info.plist'))
            binary=z.read('Payload/Livecript.app/'+info['CFBundleExecutable'])
            if binary[:4] not in (b'\xcf\xfa\xed\xfe',b'\xca\xfe\xba\xbe',b'\xbe\xba\xfe\xca'):raise ValueError('Invalid executable')
    except (zipfile.BadZipFile,KeyError,OSError,plistlib.InvalidFileException) as e:raise ValueError('Invalid IPA') from e
    if info.get('CFBundleIdentifier')!='com.leboxis.livecript' or info.get('CFBundleShortVersionString')!=version:raise ValueError('Bundle ID/version mismatch')
    source=copy.deepcopy(previous)
    source.update(name='Livecript',identifier='com.leboxis.livecript.source',subtitle='Votre voix, simplement du texte.',website='https://github.com/Leboxis/Livecript',iconURL=icon_url)
    source.setdefault('news',[])
    apps=source.setdefault('apps',[])
    app=next((a for a in apps if a['bundleIdentifier']=='com.leboxis.livecript'),None)
    if app is None:
        app={'name':'Livecript','bundleIdentifier':'com.leboxis.livecript','developerName':'Leboxis','localizedDescription':'Transcription locale avec les modèles Apple, pause et reprise, historique et vocabulaire personnalisé. iOS 26. Modèle à télécharger avant utilisation hors connexion.','iconURL':icon_url,'tintColor':'#208F77','versions':[]};apps.append(app)
    app['appPermissions']={'entitlements':[],'privacy':{k:v for k,v in info.items() if k.endswith('UsageDescription')}}
    entry={'version':version,'buildVersion':info['CFBundleVersion'],'date':date,'downloadURL':download_url,'size':ipa.stat().st_size,'minOSVersion':info['MinimumOSVersion'],'localizedDescription':'Transcription Apple locale, historique et vocabulaire personnalisé.'}
    app['versions']=[entry]+[v for v in app['versions'] if v['version']!=version]
    return source
if __name__=='__main__':
    p=argparse.ArgumentParser()
    for key in ['previous','ipa','version','date','download-url','icon-url','output']:p.add_argument('--'+key,required=True)
    a=p.parse_args();source=generate_source(json.loads(Path(a.previous).read_text()),Path(a.ipa),a.version,a.date,a.download_url,a.icon_url)
    out=Path(a.output);tmp=out.with_suffix('.tmp');tmp.write_text(json.dumps(source,ensure_ascii=False,indent=2)+'\n');tmp.replace(out)
