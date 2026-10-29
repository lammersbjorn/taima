#!/usr/bin/env python3
"""Run the complete already-built corpus under each default JVM locale."""
from pathlib import Path
import os
import subprocess

root = Path(__file__).resolve().parents[2]
os.chdir(root)
cache = Path.home() / '.gradle/caches/modules-2/files-2.1'
coordinates = [('com.google.code.gson', 'gson', '2.13.2'),
               ('junit', 'junit', '4.13.2'),
               ('org.hamcrest', 'hamcrest-core', '1.3'),
               ('org.jetbrains.kotlin', 'kotlin-stdlib', '2.4.21')]
jars = [str(next((cache / group / artifact / version).glob('*/*.jar')))
        for group, artifact, version in coordinates]
classes = ['android/core/build/classes/kotlin/main', 'android/core/build/classes/kotlin/test']
assert all(Path(folder).is_dir() for folder in classes), 'Build :core:test behind the gate first.'
java_home = Path(os.environ.get('JAVA_HOME', '/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home'))
for locale in ['nl_NL', 'de_DE', 'en_US']:
    language, country = locale.split('_')
    print(f'Default locale={locale}, timezone=Europe/Amsterdam', flush=True)
    subprocess.run([str(java_home / 'bin/java'), '-Xmx512m',
                    f'-Duser.language={language}', f'-Duser.country={country}',
                    '-Duser.timezone=Europe/Amsterdam',
                    f'-Dtaima.goldens={root / "contracts/golden"}',
                    '-cp', ':'.join(classes + jars),
                    'org.junit.runner.JUnitCore', 'nl.taima.core.ContractTest'], check=True)
