import os
from pathlib import Path
import shutil
import subprocess
import tempfile

source=Path.cwd()
with tempfile.TemporaryDirectory(prefix='taima-admission-test-') as temporary:
 root=Path(temporary);repo=root/'repo';repo.mkdir()
 home=root/'home';gate=home/'.t3/tools/saiko-load-gate/load-gate.sh'
 gate.parent.mkdir(parents=True);gate.write_text('#!/bin/sh\nexit 75\n');gate.chmod(0o755)
 (repo/'scripts/android').mkdir(parents=True)
 (repo/'Packages/TaimaCore').mkdir(parents=True)
 (repo/'android').mkdir()
 key=root/'synthetic-keystore';key.write_text('synthetic-only')
 password=root/'synthetic-password';password.write_text('synthetic-only')
 shutil.copy(source/'scripts/build-apk.sh',repo/'scripts/build-apk.sh')
 shutil.copy(source/'scripts/android/swift-build.sh',repo/'scripts/android/swift-build.sh')
 env=dict(os.environ,HOME=str(home),TAIMA_KEYSTORE=str(key),TAIMA_KEYSTORE_PASSWORD_FILE=str(password))
 # Native script must propagate denial without reaching the nonexistent compiler.
 result=subprocess.run(['bash','scripts/android/swift-build.sh','aarch64','release'],cwd=repo,env=env,capture_output=True,text=True)
 assert result.returncode==75,(result.returncode,result.stdout,result.stderr)
 # Isolate the later Gradle admission: preceding native operations are inert stubs.
 (repo/'scripts/android/swift-build.sh').write_text('#!/bin/sh\nexit 0\n')
 (repo/'scripts/android/package-jni.sh').write_text('#!/bin/sh\nexit 0\n')
 for p in (repo/'scripts/android').iterdir():p.chmod(0o755)
 (repo/'android/gradlew').write_text('#!/bin/sh\ntouch GRADLE_WAS_RUN\nexit 0\n');(repo/'android/gradlew').chmod(0o755)
 (repo/'scripts/android/run-jvm-contracts.py').write_text('raise Exception("MUST NOT RUN AFTER DENIAL")')
 subprocess.run(['git','init','-q'],cwd=repo,check=True)
 subprocess.run(['git','add','.'],cwd=repo,check=True)
 subprocess.run(['git','-c','user.name=Synthetic','-c','user.email=synthetic@example.invalid','commit','-qm','Synthetic admission fixture'],cwd=repo,check=True)
 result=subprocess.run(['bash','scripts/build-apk.sh'],cwd=repo,env=env,capture_output=True,text=True)
 assert result.returncode==75,(result.returncode,result.stdout,result.stderr)
 assert not (repo/'GRADLE_WAS_RUN').exists()
 print('PASS: native admission denial returns 75 without invoking a compiler.')
 print('PASS: Gradle admission denial returns 75 before Gradle, JVM checks or artifact copying.')
 print('Only synthetic signing paths and inert build stubs were used. Temporary fixture removed.')
