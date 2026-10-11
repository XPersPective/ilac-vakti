"""Static native policy check; not compilation, signing or device acceptance."""
from pathlib import Path
import plistlib
import re
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parent.parent
for path in (root / 'android/app/src/main').rglob('*.xml'):
    ET.parse(path)
for name in ('ios/Runner/Info.plist', 'ios/Flutter/AppFrameworkInfo.plist'):
    with (root / name).open('rb') as stream:
        plistlib.load(stream)
android = '{http://schemas.android.com/apk/res/android}'
manifest = ET.parse(root / 'android/app/src/main/AndroidManifest.xml').getroot()
assert manifest.find('application').get(android + 'allowBackup') == 'false'
assert {p.get(android + 'name') for p in manifest.findall('uses-permission')} == {
    'android.permission.POST_NOTIFICATIONS', 'android.permission.RECEIVE_BOOT_COMPLETED',
    'android.permission.SCHEDULE_EXACT_ALARM'}
assert all(r.get(android + 'exported') == 'false' for r in manifest.find('application').findall('receiver'))
for name, tags in [('backup_rules.xml', ['.']), ('data_extraction_rules.xml', ['cloud-backup', 'device-transfer'])]:
    tree = ET.parse(root / 'android/app/src/main/res/xml' / name).getroot()
    for tag in tags:
        node = tree if tag == '.' else tree.find(tag)
        assert len(node.findall('exclude')) == 9
        assert all(p.get('path') == '.' for p in node.findall('exclude'))
project = (root / 'ios/Runner.xcodeproj/project.pbxproj').read_text(encoding='utf-8')
assert set(re.findall(r'IPHONEOS_DEPLOYMENT_TARGET = ([\d.]+)', project)) == {'15.5'}
assert 'FlutterGeneratedPluginSwiftPackage' in project and 'InfoPlist.strings in Resources' in project
print('PASS: native XML/plist, permission, backup and deployment policy')
