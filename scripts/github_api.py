import json, os, subprocess, urllib.request, urllib.error
from pathlib import Path

def credentials():
    env=dict(os.environ,GIT_TERMINAL_PROMPT='0')
    r=subprocess.run(['git','credential','fill'],input='protocol=https\nhost=github.com\n\n',capture_output=True,text=True,check=True,env=env)
    fields=dict(x.split('=',1) for x in r.stdout.splitlines() if '=' in x)
    return fields['password']

def api(method,path,data=None,raw=None,content_type=None):
    url=path if path.startswith('https://') else 'https://api.github.com'+path
    if urllib.parse.urlparse(url).hostname not in ('api.github.com','uploads.github.com'):
        raise ValueError('Unapproved API host')
    body=raw if raw is not None else (json.dumps(data).encode() if data is not None else None)
    req=urllib.request.Request(url,data=body,method=method,headers={'Authorization':'Bearer '+credentials(),'Accept':'application/vnd.github+json','X-GitHub-Api-Version':'2022-11-28','User-Agent':'Yi-release-tool','Content-Type':content_type or 'application/json'})
    opener=urllib.request.build_opener(urllib.request.ProxyHandler({}))
    try:
        with opener.open(req,timeout=90) as response:
            result=response.read()
            return json.loads(result) if result else None
    except urllib.error.HTTPError as e:
        detail=e.read().decode(errors='replace')
        raise RuntimeError(f'GitHub {method} {path}: HTTP {e.code}: {detail}') from None
