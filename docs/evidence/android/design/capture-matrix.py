import subprocess,re,sys
from pathlib import Path
import os
cli=os.environ['TAIMA_DEVICE_COMMAND'] # Exact command returned by T3 device_open.
lang,theme,scale=sys.argv[1:]
root=Path(os.environ['TAIMA_DESIGN_EVIDENCE']);screens=root/'screens';screens.mkdir(exist_ok=True)
prefix=f'{lang}-{theme}-{scale}'
log=(root/f'{prefix}.log').open('w')
def run(*args):
 p=subprocess.run([cli,*args],text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
 log.write('agent-device '+' '.join(args)+'\n'+p.stdout+'\n');log.flush()
 if p.returncode: raise RuntimeError(p.stdout)
 return p.stdout
def snap():return run('snapshot','-i')
def tap(label,prefix=False):
 s=snap()
 matches=re.findall(r'^(@\S+) \[group\] "([^"\n]+)"',s,re.M)
 found=[ref for ref,text in matches if (text.startswith(label) if prefix else text==label)]
 if not found: raise RuntimeError(f'Missing {label}: {s}')
 run('press',found[0],'--settle')
def shot(name):
 run('screenshot',str(screens/f'{prefix}-{name}.png'));print(prefix,name,flush=True)
run('settings','appearance',theme)
run('settings','text-size','large' if scale=='normal' else 'accessibility-extra-large')
run('settings','text-size','--json')
run('open','nl.taima.android','--activity','nl.taima.android/nl.taima.MainActivity','--relaunch')
# Force readiness through a snapshot before taking the first screen.
s=snap();assert ('Northern Lights' in s),s
shot('Collection')
tap('Stash' if lang=='en' else 'Voorraad');shot('Stash')
if scale=='normal' and lang=='en':
 run('scroll','down','0.7','--settle');shot('Stash-recent')
tap('Stats' if lang=='en' or scale=='normal' else 'Statistieken');shot('Stats')
if scale=='normal' and lang=='en':
 for n in range(3):
  run('scroll','down','0.7','--settle');shot(f'Stats-charts-{n+1}')
tap('Library' if lang=='en' else ('Bieb' if scale=='normal' else 'Bibliotheek'))
# Capture a useful local search, with the real keyboard dismissed.
s=snap();field=re.search(r'^(@\S+) \[text-field\]',s,re.M);assert field,s
run('fill',field[1],'Haze','--settle')
s=snap();back=re.search(r'^(@\S+) \[image\] "Back"',s,re.M)
if back:run('press',back[1],'--settle')
shot('Library')
tap('More' if lang=='en' else 'Meer');shot('More')
tap('Play' if lang=='en' else 'Spelen',prefix=True)
tap('Next card' if lang=='en' else 'Volgende kaart')
s=snap();assert ('Close deck' if lang=='en' else 'Kaartspel sluiten') in s,s
shot('Party')
log.close()
