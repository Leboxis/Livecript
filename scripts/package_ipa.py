"""Package a compiled iOS app, preserving executable modes, for sideload signing."""
import argparse, plistlib, zipfile
from pathlib import Path

def package_ipa(app_path: Path, output: Path) -> None:
    if not app_path.is_dir() or not (app_path/'Info.plist').is_file():
        raise ValueError('A compiled .app bundle is required')
    with (app_path/'Info.plist').open('rb') as f: info=plistlib.load(f)
    executable=app_path/info.get('CFBundleExecutable','')
    if not executable.is_file() or executable.read_bytes()[:4] not in (b'\xcf\xfa\xed\xfe',b'\xca\xfe\xba\xbe',b'\xbe\xba\xfe\xca'):
        raise ValueError('Missing Mach-O executable')
    output.parent.mkdir(parents=True,exist_ok=True)
    temporary=output.with_suffix('.tmp')
    try:
        with zipfile.ZipFile(temporary,'w',zipfile.ZIP_DEFLATED) as archive:
            for path in sorted(app_path.rglob('*')):
                if path.is_file(): archive.write(path,Path('Payload')/app_path.name/path.relative_to(app_path))
        temporary.replace(output)
    finally: temporary.unlink(missing_ok=True)
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--app',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();package_ipa(a.app,a.output)
