$ip='192.168.0.2'
$port=1402

function Invoke-Cmd([string]$cmd,[int]$maxSec=12){
  $c=New-Object System.Net.Sockets.TcpClient
  $c.Connect($ip,$port)
  $s=$c.GetStream()
  $s.ReadTimeout=1200
  $b=[Text.Encoding]::ASCII.GetBytes("$cmd`r`n")
  $s.Write($b,0,$b.Length)

  $start=Get-Date
  $all=''
  $lastData=Get-Date

  while(((Get-Date)-$start).TotalSeconds -lt $maxSec){
    try{
      $buf=New-Object byte[] 4096
      $r=$s.Read($buf,0,$buf.Length)
      if($r -gt 0){
        $chunk=[Text.Encoding]::ASCII.GetString($buf,0,$r)
        $all += $chunk
        $lastData=Get-Date
        if($all -match '<STATUS>'){ break }
      }
    } catch [System.IO.IOException] {
      if(((Get-Date)-$lastData).TotalMilliseconds -gt 1800){ break }
    }
  }

  $c.Close()
  return $all
}

Write-Host '--- REPRO START ---'
Write-Host '1) Stop'
Write-Host (Invoke-Cmd 'Stop -all' 6)

Write-Host '2) Unload'
Write-Host (Invoke-Cmd 'Unload GPL_Code' 6)

Write-Host '3) Compile before load (expected possible -508)'
Write-Host (Invoke-Cmd 'Compile GPL_Code' 10)

Write-Host '4) Load abs path'
Write-Host (Invoke-Cmd 'Load /flash/projects/GPL_Code' 8)

Write-Host '5) Compile after load #1'
Write-Host (Invoke-Cmd 'Compile GPL_Code' 14)

Write-Host '6) Compile after load #2 (retry)'
Write-Host (Invoke-Cmd 'Compile GPL_Code' 14)

Write-Host '7) Start'
Write-Host (Invoke-Cmd 'Start GPL_Code' 8)

Write-Host '8) Show Thread'
Write-Host (Invoke-Cmd 'Show Thread' 8)

Write-Host '9) ErrorLog'
Write-Host (Invoke-Cmd 'ErrorLog' 8)
Write-Host '--- REPRO END ---'
