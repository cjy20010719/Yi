#!/usr/bin/env python3
"""Build isolated 1.0.0 -> 1.0.1 Sparkle test apps, never replacing /Applications/Yi.app."""
import plistlib,shutil,subprocess,tempfile,shlex
from pathlib import Path
root=Path(__file__).resolve().parents[1];stage=Path(tempfile.mkdtemp(prefix='yi-update-test-',dir=root/'dist'))
for version,build,folder in [('1.0.0','100','installed'),('1.0.1','101','candidate')]:
 app=stage/folder/'Yi Update Test.app'
 for path in ['MacOS','Resources','Frameworks']:(app/'Contents'/path).mkdir(parents=True,exist_ok=True)
 subprocess.run(['ditto',str(root/'Vendor/Sparkle/Sparkle.framework'),str(app/'Contents/Frameworks/Sparkle.framework')],check=True)
 shutil.copy2(root/'Assets/AppIcon.icns',app/'Contents/Resources/AppIcon.icns')
 d=plistlib.loads((root/'Info.plist').read_bytes());d.update(CFBundleIdentifier='local.Yi.UpdateSmoke',CFBundleName='Yi Update Test',CFBundleDisplayName='Yi Update Test',CFBundleExecutable='YiUpdateTest',CFBundleShortVersionString=version,CFBundleVersion=build,LSUIElement=False,SUFeedURL='http://127.0.0.1:18764/appcast.xml',SUEnableAutomaticChecks=False,NSAppTransportSecurity={'NSAllowsLocalNetworking':True})
 (app/'Contents/Info.plist').write_bytes(plistlib.dumps(d))
 subprocess.run(['clang','-fobjc-arc','-fblocks','-O2','-arch','arm64','-arch','x86_64','-mmacosx-version-min=13.0',str(root/'tests/update-smoke.m'),'-framework','Cocoa','-F',str(root/'Vendor/Sparkle'),'-framework','Sparkle','-Wl,-rpath,@executable_path/../Frameworks','-o',str(app/'Contents/MacOS/YiUpdateTest')],check=True)
 subprocess.run(['codesign','--force','--sign','-','--identifier','local.Yi.UpdateSmoke',str(app)],check=True)
server=stage/'server';server.mkdir()
archive=server/'Yi-1.0.1.zip'
subprocess.run(['ditto','-c','-k','--sequesterRsrc','--keepParent',str(stage/'candidate/Yi Update Test.app'),str(archive)],check=True)
subprocess.run(['python3',str(root/'scripts/make-appcast.py'),str(archive),'--url','http://127.0.0.1:18764/Yi-1.0.1.zip','--output',str(server/'appcast.xml')],check=True)
print('Start server: python3 -m http.server 18764 --bind 127.0.0.1 --directory '+shlex.quote(str(server)))
print('Open test app in Finder:',stage/'installed/Yi Update Test.app')
print('Click Check for Updates -> Install Update -> Install and Relaunch. Verify 1.0.1 and installed/launches.txt.')
