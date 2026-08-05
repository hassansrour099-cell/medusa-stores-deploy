# Requires Contabo root password once:
#   $env:CONTABO_ROOT_PASSWORD = 'your-password'
#   .\scripts\ssh-bootstrap.ps1

$ErrorActionPreference = "Stop"
$ip = "169.58.124.240"
$key = Join-Path $env:USERPROFILE ".ssh\contabo_medusa"
$pub = "$key.pub"

if (-not $env:CONTABO_ROOT_PASSWORD) {
  Write-Error "Set CONTABO_ROOT_PASSWORD to the Contabo root password, then re-run."
}

if (-not (Test-Path $key)) {
  Write-Error "Missing SSH key at $key — generate with ssh-keygen first."
}

$pubKey = (Get-Content $pub -Raw).Trim()

# Install pip/paramiko if needed for password+key bootstrap
python -c "import paramiko" 2>$null
if ($LASTEXITCODE -ne 0) {
  python -m pip install --user paramiko 2>&1 | Select-Object -Last 5
}

$py = @"
import os, paramiko
ip = '$ip'
password = os.environ['CONTABO_ROOT_PASSWORD']
pub = '''$pubKey'''
client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(ip, username='root', password=password, timeout=30, allow_agent=False, look_for_keys=False)
cmds = [
  'mkdir -p /root/.ssh && chmod 700 /root/.ssh',
  f"grep -qxF '{pub}' /root/.ssh/authorized_keys || echo '{pub}' >> /root/.ssh/authorized_keys",
  'chmod 600 /root/.ssh/authorized_keys',
  'curl -fsSL https://raw.githubusercontent.com/hassansrour099-cell/medusa-stores-deploy/master/scripts/remote-bootstrap.sh | bash',
]
for c in cmds:
    print('>>', c[:80])
    stdin, stdout, stderr = client.exec_command(c, get_pty=True, timeout=3600)
    print(stdout.read().decode(errors='replace'))
    err = stderr.read().decode(errors='replace')
    if err:
        print(err)
    code = stdout.channel.recv_exit_status()
    if code != 0:
        raise SystemExit(f'Command failed ({code}): {c[:120]}')
client.close()
print('DONE')
"@

$env:CONTABO_ROOT_PASSWORD = $env:CONTABO_ROOT_PASSWORD
python -c $py
