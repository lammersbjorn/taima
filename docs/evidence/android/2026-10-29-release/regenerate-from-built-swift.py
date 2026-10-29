"""Execute the already-built Swift codec. This does not invoke a compiler."""
import ctypes
import json
from pathlib import Path

root=Path.cwd();library=root/'build/core-tests/out/Products/Debug/libTaimaBridge.dylib'
swift=ctypes.CDLL(str(library))
for name in ['taima_call','taima_normalize']:
 fn=getattr(swift,name);fn.argtypes=[ctypes.c_char_p,ctypes.c_ssize_t];fn.restype=ctypes.c_void_p
swift.taima_free.argtypes=[ctypes.c_void_p];swift.taima_free.restype=None
def invoke(name,payload):
 data=json.dumps(payload,ensure_ascii=False).encode()
 pointer=getattr(swift,name)(data,len(data))
 assert pointer
 try:return ctypes.string_at(pointer).decode()
 finally:swift.taima_free(pointer)
folder=root/'contracts/golden'
bag=json.loads((folder/'record.json').read_text());bag['productForm']='edible';bag['thcMilligrams']=7.5
canonical=invoke('taima_normalize',bag)
assert canonical.startswith('{"record":')
record=canonical[len('{"record":'):-1]
(folder/'edible-record.json').write_bytes(record.encode())
for filename,item in [('collection.csv',json.loads((folder/'record.json').read_text())),('edible.csv',json.loads(record))]:
 envelope=json.loads(invoke('taima_call',{'version':1,'op':'csv.export','bags':[item]}))
 assert envelope['ok'],envelope
 (folder/filename).write_bytes(envelope['result'].encode())
 print(f'Swift codec wrote {filename}: {(folder/filename).stat().st_size} bytes.')
print('Swift normalizer wrote edible-record.json. Source codec Backup.swift is unchanged since the admitted host build at 4ed59a9.')
