param([string]$Phase = "all")

$ip = "192.168.0.2"
$port = 1402

function Send1402([string]$cmd, [int]$waitMs = 1500) {
    try {
        $c = New-Object System.Net.Sockets.TcpClient
        $c.Connect($ip, $port)
        $st = $c.GetStream()
        $st.ReadTimeout = 5000
        $b = [System.Text.Encoding]::ASCII.GetBytes("$cmd`r`n")
        $st.Write($b, 0, $b.Length)
        Start-Sleep -Milliseconds $waitMs
        $buf = New-Object byte[] 16384
        $r = $st.Read($buf, 0, $buf.Length)
        $c.Close()
        return [System.Text.Encoding]::ASCII.GetString($buf, 0, $r)
    } catch {
        return "ERROR: $_"
    }
}

function FtpUpload([string]$localPath, [string]$remotePath) {
    try {
        $uri = "ftp://${ip}${remotePath}"
        $req = [System.Net.FtpWebRequest]::Create($uri)
        $req.Method = [System.Net.WebRequestMethods+Ftp]::UploadFile
        $req.Credentials = New-Object System.Net.NetworkCredential("robot", "")
        $req.UseBinary = $true
        $req.UsePassive = $true
        $content = [System.IO.File]::ReadAllBytes($localPath)
        $req.ContentLength = $content.Length
        $rs = $req.GetRequestStream()
        $rs.Write($content, 0, $content.Length)
        $rs.Close()
        $resp = $req.GetResponse()
        $status = $resp.StatusDescription
        $resp.Close()
        return "OK: $status"
    } catch {
        return "FAIL: $_"
    }
}

function FtpMkdir([string]$remotePath) {
    try {
        $uri = "ftp://${ip}${remotePath}"
        $req = [System.Net.FtpWebRequest]::Create($uri)
        $req.Method = [System.Net.WebRequestMethods+Ftp]::MakeDirectory
        $req.Credentials = New-Object System.Net.NetworkCredential("robot", "")
        $resp = $req.GetResponse()
        $resp.Close()
        return "Created"
    } catch {
        return "Exists or Error: $($_.Exception.Message)"
    }
}

Write-Host "============================================================"
Write-Host " GPL Debug Cycle - $(Get-Date -Format 'HH:mm:ss')"
Write-Host "============================================================"

# 1. Stop
Write-Host "`n[STEP 1] Stop -all"
$r = Send1402 "Stop -all" 2000
Write-Host $r

# 2. Unload
Write-Host "`n[STEP 2] Unload GPL_Code"
$r = Send1402 "Unload GPL_Code" 2000
Write-Host $r

# 3. FTP Upload
Write-Host "`n[STEP 3] FTP Upload to /flash/projects/GPL_Code"
FtpMkdir "/flash/projects/GPL_Code" | Out-Null

$projectDir = "C:\Users\Doyun\Documents\GitHub\RND 로봇\Broosk Controllers\projects\GPL_Code"
$files = Get-ChildItem $projectDir -File
foreach ($f in $files) {
    $remotePath = "/flash/projects/GPL_Code/$($f.Name)"
    $result = FtpUpload $f.FullName $remotePath
    Write-Host "  $($f.Name): $result"
}

# 4. Load
Write-Host "`n[STEP 4] Load /flash/projects/GPL_Code"
$r = Send1402 "Load /flash/projects/GPL_Code" 3000
Write-Host $r

# 5. Compile
Write-Host "`n[STEP 5] Compile GPL_Code"
$r = Send1402 "Compile GPL_Code" 8000
Write-Host $r

# 6. Start
Write-Host "`n[STEP 6] Start GPL_Code"
$r = Send1402 "Start GPL_Code" 3000
Write-Host $r

# 7. Check
Start-Sleep -Seconds 2
Write-Host "`n[STEP 7] Show Thread"
$r = Send1402 "Show Thread" 2000
Write-Host $r

Write-Host "`n[STEP 8] ErrorLog"
$r = Send1402 "ErrorLog" 2000
Write-Host $r

Write-Host "`n============================================================"
Write-Host " Cycle Complete - $(Get-Date -Format 'HH:mm:ss')"
Write-Host "============================================================"
