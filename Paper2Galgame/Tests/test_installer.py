import importlib.util,re,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('installer',ROOT/'Scripts/install_runtime.py');installer=importlib.util.module_from_spec(spec);spec.loader.exec_module(installer)
class IntegrationContractTests(unittest.TestCase):
 def test_download_allowlist_excludes_credentials_and_art(self):
  self.assertEqual(set(installer.FILES),{'components/GameScreen.tsx','types.ts'})
  self.assertEqual(len(installer.REVISION),40)
 def test_patches_fail_closed_for_changed_upstream(self):
  with self.assertRaises(ValueError):installer.patch_game('export default function changed() {}')
 def test_local_web_network_is_disabled(self):
  index=(ROOT/'Web/index.html').read_text()
  for token in ["connect-src 'none'","object-src 'none'","frame-src 'none'","form-action 'none'"]:self.assertIn(token,index)
 def test_built_runtime_has_no_upstream_hosts_or_credentials(self):
  runtime=ROOT/'Resources/Runtime'
  if not runtime.exists():self.skipTest('Run local installer first')
  all_text='\n'.join(p.read_text() for p in runtime.rglob('*') if p.suffix in ['.js','.html','.css','.json'])
  for forbidden in ['pic.imgdd.cc','pic1.imgdb.cn','generativelanguage.googleapis','esm.sh','cdn.tailwindcss.com','google/genai']:
   self.assertNotIn(forbidden,all_text)
  self.assertIsNone(re.search(r'(?:sk-|AIza)[A-Za-z0-9_-]{20,}',all_text))
  self.assertIn('Dialogue History',all_text)
  self.assertIn('lumapPaper2GalgameLoad',all_text)
  html=(runtime/'index.html').read_text()
  self.assertNotIn('type="module"',html)
  self.assertIn('src="./runtime.js"',html)
  self.assertTrue((runtime/'style.css').exists())
if __name__=='__main__':unittest.main()
