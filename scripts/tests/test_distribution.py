import unittest, tempfile, plistlib, zipfile, sys, copy
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from package_ipa import package_ipa
from generate_source import generate_source

class DistributionTests(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup);self.root=Path(self.tmp.name)
  self.app=self.root/'Livecript.app';self.app.mkdir()
  (self.app/'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier':'com.leboxis.livecript','CFBundleExecutable':'Livecript','CFBundleShortVersionString':'1.0.0','CFBundleVersion':'1','MinimumOSVersion':'26.0','NSMicrophoneUsageDescription':'Microphone local'}))
  (self.app/'Livecript').write_bytes(b'\xcf\xfa\xed\xfe'+b'\x00'*28);(self.app/'Livecript').chmod(0o755)
  self.ipa=self.root/'Livecript.ipa'
 def make(self):
  package_ipa(self.app,self.ipa)
  return generate_source({'name':'Livecript','apps':[],'news':[]},self.ipa,'1.0.0','2026-10-08T16:00:00Z','https://github.com/Leboxis/Livecript/releases/download/v1.0.0/Livecript.ipa','https://example.com/icon.png')
 def test_missing_app_rejected(self):
  with self.assertRaises(ValueError):package_ipa(self.root/'missing.app',self.ipa)
 def test_archive_contains_bundle(self):
  self.make()
  with zipfile.ZipFile(self.ipa) as z:self.assertIn('Payload/Livecript.app/Livecript',z.namelist())
 def test_real_size_and_idempotency(self):
  source=self.make();v=source['apps'][0]['versions'][0];self.assertEqual(v['size'],self.ipa.stat().st_size)
  again=generate_source(source,self.ipa,'1.0.0',v['date'],v['downloadURL'],'https://example.com/icon.png')
  self.assertEqual(len(again['apps'][0]['versions']),1)
 def test_preserve_versions_without_mutation(self):
  source=self.make();source['apps'][0]['versions'][0]['version']='0.9.0';previous=copy.deepcopy(source)
  updated=generate_source(source,self.ipa,'1.0.0','2026-10-08','https://example.com/app.ipa','https://example.com/icon.png')
  self.assertEqual([v['version'] for v in updated['apps'][0]['versions']],['1.0.0','0.9.0']);self.assertEqual(source,previous)
 def test_invalid_ipa_rejected(self):
  self.ipa.write_text('not an ipa')
  with self.assertRaises(ValueError):generate_source({},self.ipa,'1.0.0','2026-10-08','https://example.com/a.ipa','https://example.com/i.png')
 def test_mismatched_version_rejected(self):
  self.make()
  with self.assertRaises(ValueError):generate_source({},self.ipa,'9.0.0','2026-10-08','https://example.com/a.ipa','https://example.com/i.png')
if __name__=='__main__':unittest.main()
