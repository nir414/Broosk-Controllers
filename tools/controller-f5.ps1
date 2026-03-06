param(
    [string]$ControllerIp = "192.168.0.2",
    [int]$ControllerPort = 1402,
    [string]$ProjectRootDir = "$PSScriptRoot\..\projects",
    [string]$ProjectKey = "",
    [string]$LocalProjectDir = "",
    [string]$FtpProjectDir = "",
    [string]$LoadPath = "",
    [string]$ProjectName = "",
    [switch]$FollowRuntimeConsole,
    [int]$RuntimeConsolePort = 1403,
    [int]$RuntimeReconnectMs = 1000,
    [switch]$RuntimeConsoleRaw,
    [string]$RuntimeFilter = "",
    [int]$RuntimeConsoleDurationSec = 0,
    [switch]$RuntimeNoReconnect,
    [switch]$RuntimeExitOnDisconnect,
    [switch]$FollowRuntimeLog,
    [string]$RuntimeLogPath = "/ROMDISK/tmp/Test.log",
    [int]$FollowDurationSec = 30,
    [int]$FollowIntervalMs = 500,
    [switch]$EnableFileLog,
    [switch]$DebugSnapshot,
    [switch]$DebugSnapshotOnError,
    [switch]$SkipUnchanged,
    [switch]$VerifySize,
    [switch]$SkipStart
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$NetTimeoutMs = 10000
$FtpRetries = 1
$LogFile = Join-Path $PSScriptRoot "controller-f5.log"

function Write-Step([string]$Message) {
    $line = "[F5] $Message"
    Write-Host $line
    if ($EnableFileLog) {
        try {
            Add-Content -Path $LogFile -Value ("{0} {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"), $line)
        }
        catch {
            # 로그 파일 잠금 시에도 주 플로우는 계속 진행
        }
    }
}

function Write-ConsoleLine([string]$Message) {
    if ([string]::IsNullOrWhiteSpace($Message)) { return }
    Write-Host "[CONSOLE] $Message"
    if ($EnableFileLog) {
        try {
            Add-Content -Path $LogFile -Value ("{0} [CONSOLE] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"), $Message)
        }
        catch {
            # 로그 파일 잠금 시에도 주 플로우는 계속 진행
        }
    }
}

function Format-ByteSize([long]$Bytes) {
    if ($Bytes -lt 1024) {
        return "$Bytes B"
    }
    elseif ($Bytes -lt 1048576) {
        return ("{0:N1} KB" -f ($Bytes / 1KB))
    }
    elseif ($Bytes -lt 1073741824) {
        return ("{0:N2} MB" -f ($Bytes / 1MB))
    }
    else {
        return ("{0:N2} GB" -f ($Bytes / 1GB))
    }
}

function Get-RemoteDirPath([string]$RemoteFilePath) {
    if ([string]::IsNullOrWhiteSpace($RemoteFilePath)) { return "" }
    $p = $RemoteFilePath.Replace('\\', '/')
    $idx = $p.LastIndexOf('/')
    if ($idx -le 0) { return "" }
    return $p.Substring(0, $idx)
}

function Invoke-WithRetry {
    param(
        [Parameter(Mandatory = $true)][scriptblock]$Action,
        [string]$Name = "operation",
        [int]$RetryCount = 1
    )

    $lastError = $null
    for ($attempt = 0; $attempt -le $RetryCount; $attempt++) {
        try {
            return & $Action
        }
        catch {
            $lastError = $_
            if ($attempt -lt $RetryCount) {
                Write-Host "[RETRY] $Name failed (attempt $($attempt + 1)). retrying..."
                Start-Sleep -Milliseconds 400
            }
        }
    }

    throw $lastError
}

function New-FtpRequest {
    param(
        [Parameter(Mandatory = $true)][string]$Uri,
        [Parameter(Mandatory = $true)][string]$Method,
        [bool]$UsePassive = $true
    )

    $req = [System.Net.FtpWebRequest]::Create($Uri)
    $req.Method = $Method
    $req.Credentials = [System.Net.NetworkCredential]::new("anonymous", "anonymous")
    $req.UseBinary = $true
    $req.KeepAlive = $false
    $req.UsePassive = $UsePassive
    $req.Timeout = $NetTimeoutMs
    $req.ReadWriteTimeout = $NetTimeoutMs
    return $req
}

function Send-ConsoleCommand {
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [int]$ReadTimeoutMs = $NetTimeoutMs
    )

    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $connectTask = $client.ConnectAsync($ControllerIp, $ControllerPort)
        if (-not $connectTask.Wait($NetTimeoutMs)) {
            throw "Console connect timeout (${NetTimeoutMs}ms): ${ControllerIp}:$ControllerPort"
        }
        $stream = $client.GetStream()
        $stream.ReadTimeout = $ReadTimeoutMs
        $stream.WriteTimeout = $ReadTimeoutMs

        $payload = [System.Text.Encoding]::ASCII.GetBytes($Command + "`r`n")
        $stream.Write($payload, 0, $payload.Length)
        $stream.Flush()

        $buffer = New-Object byte[] 4096
        $builder = New-Object System.Text.StringBuilder
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        while ($sw.ElapsedMilliseconds -lt $ReadTimeoutMs) {
            if ($stream.DataAvailable) {
                $read = $stream.Read($buffer, 0, $buffer.Length)
                if ($read -le 0) { break }
                [void]$builder.Append([System.Text.Encoding]::ASCII.GetString($buffer, 0, $read))

                $textNow = $builder.ToString()
                if ($textNow -match "</STATUS>") {
                    break
                }
            }
            else {
                Start-Sleep -Milliseconds 80
            }
        }

        $response = $builder.ToString().Trim()
        Write-ConsoleLine $response

        if ($response -match "<STATUS>\s*(-?[0-9]+)") {
            $statusCode = [int]$Matches[1]
            if ($statusCode -ne 0) {
                throw "Console command failed: $Command | $response"
            }
        }

        if ($response -eq "") {
            Write-Step "Console response empty for command: $Command"
        }

        return $response
    }
    finally {
        if ($client.Connected) { $client.Close() }
    }
}

function Try-SendConsoleCommand {
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [int]$ReadTimeoutMs = $NetTimeoutMs,
        [switch]$Quiet
    )

    try {
        return Send-ConsoleCommand -Command $Command -ReadTimeoutMs $ReadTimeoutMs
    }
    catch {
        if (-not $Quiet) {
            Write-Step "Best-effort command failed: $Command | $($_.Exception.Message)"
        }
        return $null
    }
}

function Invoke-DebugSnapshot {
    param(
        [string]$ThreadName = "",
        [string]$Reason = "manual"
    )

    Write-Step "Collect debug snapshot (reason=$Reason, thread=$ThreadName)"

    $commands = New-Object System.Collections.Generic.List[string]
    [void]$commands.Add("Show Thread -stack -web")
    [void]$commands.Add("Show Break")
    [void]$commands.Add("Show Memory -all")
    [void]$commands.Add("ErrorLog -web")

    if (-not [string]::IsNullOrWhiteSpace($ThreadName)) {
        [void]$commands.Add("Show Thread $ThreadName -stack")
        [void]$commands.Add("Show Stack $ThreadName")
    }

    foreach ($cmd in $commands) {
        $null = Try-SendConsoleCommand -Command $cmd -Quiet
    }
}

function Invoke-FtpAction {
    param(
        [Parameter(Mandatory = $true)][scriptblock]$Action,
        [Parameter(Mandatory = $true)][string]$Name,
        [switch]$Quiet
    )

    $lastError = $null
    foreach ($passive in @($true, $false)) {
        for ($attempt = 0; $attempt -le $FtpRetries; $attempt++) {
            try {
                return & $Action $passive
            }
            catch {
                $lastError = $_
                if ($attempt -lt $FtpRetries) {
                    if (-not $Quiet) {
                        Write-Step "$Name failed (passive=$passive, retry=$($attempt + 1))"
                    }
                    Start-Sleep -Milliseconds 250
                }
            }
        }
    }
    throw $lastError
}

function New-FtpDirectoryIfNeeded {
    param(
        [Parameter(Mandatory = $true)][string]$BaseFtpUri,
        [Parameter(Mandatory = $true)][string]$DirPath
    )

    $normalized = $DirPath.Trim("/")
    if ([string]::IsNullOrWhiteSpace($normalized)) { return }

    $parts = $normalized.Split("/")
    $current = ""
    foreach ($part in $parts) {
        if ($current -eq "") {
            $current = "/$part"
        }
        else {
            $current = "$current/$part"
        }

        $uri = "$BaseFtpUri$current"
        try {
            Invoke-FtpAction -Name "mkdir $current" -Action {
                param($passive)
                $req = New-FtpRequest -Uri $uri -Method ([System.Net.WebRequestMethods+Ftp]::MakeDirectory) -UsePassive $passive
                $resp = $req.GetResponse()
                try { }
                finally { $resp.Close() }
            }
        }
        catch {
            # 이미 존재(550) 등은 무시
        }
    }
}

function Send-FtpFile {
    param(
        [Parameter(Mandatory = $true)][string]$BaseFtpUri,
        [Parameter(Mandatory = $true)][string]$RemotePath,
        [Parameter(Mandatory = $true)][string]$LocalPath
    )

    $targetUri = "$BaseFtpUri$RemotePath"

    # 1) curl 우선 사용 (구형 FTP 서버 호환성 향상)
    $curlArgs = @(
        "--silent",
        "--show-error",
        "--ftp-create-dirs",
        "--disable-epsv",
        "--user", "anonymous:anonymous",
        "--connect-timeout", [Math]::Ceiling($NetTimeoutMs / 1000),
        "--max-time", [Math]::Ceiling($NetTimeoutMs / 1000),
        "-T", $LocalPath,
        $targetUri
    )

    & curl.exe @curlArgs
    if ($LASTEXITCODE -eq 0) {
        return
    }

    Write-Step "curl upload failed, fallback to .NET FTP: $RemotePath"
    $fileBytes = [System.IO.File]::ReadAllBytes($LocalPath)

    Invoke-FtpAction -Name "upload $RemotePath" -Action {
        param($passive)
        $req = New-FtpRequest -Uri $targetUri -Method ([System.Net.WebRequestMethods+Ftp]::UploadFile) -UsePassive $passive
        $req.ContentLength = $fileBytes.Length

        $reqStream = $req.GetRequestStream()
        try {
            $reqStream.Write($fileBytes, 0, $fileBytes.Length)
        }
        finally {
            $reqStream.Close()
        }

        $resp = $req.GetResponse()
        try { }
        finally { $resp.Close() }
    }
}

function Get-FtpFileSize {
    param(
        [Parameter(Mandatory = $true)][string]$BaseFtpUri,
        [Parameter(Mandatory = $true)][string]$RemotePath,
        [switch]$Quiet
    )

    $targetUri = "$BaseFtpUri$RemotePath"
    return Invoke-FtpAction -Name "size $RemotePath" -Quiet:$Quiet -Action {
        param($passive)
        $req = New-FtpRequest -Uri $targetUri -Method ([System.Net.WebRequestMethods+Ftp]::GetFileSize) -UsePassive $passive
        $resp = $req.GetResponse()
        try {
            return $resp.ContentLength
        }
        finally {
            $resp.Close()
        }
    }
}

function Get-FtpBytesFromOffset {
    param(
        [Parameter(Mandatory = $true)][string]$BaseFtpUri,
        [Parameter(Mandatory = $true)][string]$RemotePath,
        [long]$Offset = 0,
        [switch]$Quiet
    )

    $targetUri = "$BaseFtpUri$RemotePath"
    return Invoke-FtpAction -Name "download $RemotePath" -Quiet:$Quiet -Action {
        param($passive)
        $req = New-FtpRequest -Uri $targetUri -Method ([System.Net.WebRequestMethods+Ftp]::DownloadFile) -UsePassive $passive
        if ($Offset -gt 0) {
            $req.ContentOffset = $Offset
        }

        $resp = $req.GetResponse()
        try {
            $stream = $resp.GetResponseStream()
            try {
                $ms = New-Object System.IO.MemoryStream
                try {
                    $stream.CopyTo($ms)
                    return $ms.ToArray()
                }
                finally {
                    $ms.Close()
                }
            }
            finally {
                $stream.Close()
            }
        }
        finally {
            $resp.Close()
        }
    }
}

function Watch-RuntimeLog {
    param(
        [Parameter(Mandatory = $true)][string]$BaseFtpUri,
        [Parameter(Mandatory = $true)][string]$RemotePath,
        [int]$DurationSec = 30,
        [int]$IntervalMs = 500
    )

    if ($DurationSec -lt 1) { $DurationSec = 1 }
    if ($IntervalMs -lt 100) { $IntervalMs = 100 }

    Write-Step "Follow runtime log: path=$RemotePath, duration=${DurationSec}s, interval=${IntervalMs}ms"

    $offset = 0L
    try {
        $offset = [long](Get-FtpFileSize -BaseFtpUri $BaseFtpUri -RemotePath $RemotePath -Quiet)
    }
    catch {
        $offset = 0L
    }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $DurationSec) {
        try {
            $remoteSize = [long](Get-FtpFileSize -BaseFtpUri $BaseFtpUri -RemotePath $RemotePath -Quiet)
            if ($remoteSize -lt $offset) {
                $offset = 0L
            }

            if ($remoteSize -gt $offset) {
                $bytes = Get-FtpBytesFromOffset -BaseFtpUri $BaseFtpUri -RemotePath $RemotePath -Offset $offset -Quiet
                if ($null -ne $bytes -and $bytes.Length -gt 0) {
                    $text = [System.Text.Encoding]::ASCII.GetString($bytes)
                    $lines = $text -split "`r?`n"
                    foreach ($line in $lines) {
                        if (-not [string]::IsNullOrWhiteSpace($line)) {
                            Write-Host "[RUNTIME] $line"
                        }
                    }
                    $offset = $offset + $bytes.Length
                }
            }
        }
        catch {
            # 실시간 로그 폴링 실패는 비치명 (다음 루프에서 재시도)
        }

        Start-Sleep -Milliseconds $IntervalMs
    }
}

function Watch-RuntimeConsole {
    param(
        [string]$HostName,
        [int]$Port = 1403,
        [int]$ReconnectMs = 1000,
        [string]$StartProjectName = "",
        [bool]$Raw = $false,
        [string]$Filter = "",
        [int]$DurationSec = 0,
        [bool]$NoReconnect = $false,
        [bool]$ExitOnDisconnect = $false
    )

    function Convert-RuntimeLine([string]$Line, [bool]$RawMode) {
        if ($null -eq $Line) { return "" }
        $s = ($Line -replace "`0", "" -replace "`r", "").Trim()
        if ($s -eq "") { return "" }
        if ($RawMode) { return $s }

        if ($s -eq "</E>") { return "" }
        if ($s -match '^<E>\d+,\d+</E>$') { return "" }

        $proj = ""
        if ($s -match '<E>\d+,([^<]+)<L>\d+</L>') {
            $proj = $Matches[1].Trim()
        }

        $msg = $s -replace '^.*<L>\d+</L>', ''
        $msg = $msg -replace '</E>$', ''
        $msg = $msg.Trim()

        if ($msg -ne "" -and ($msg -ne $s -or $proj -ne "")) {
            if ($msg -eq "") { return "" }
            if ($proj -ne "") {
                return "[$proj] $msg"
            }
            return $msg
        }

        if ($s -match '^<E>\d+,(.*)</E>$') {
            return $Matches[1].Trim()
        }

        return $s
    }

    if ($ReconnectMs -lt 100) { $ReconnectMs = 100 }
    if ($DurationSec -lt 0) { $DurationSec = 0 }
    if ($DurationSec -gt 0) {
        Write-Step "Follow runtime console: ${HostName}:$Port (duration=${DurationSec}s)"
    }
    else {
        Write-Step "Follow runtime console: ${HostName}:$Port (stop with Ctrl+C)"
    }

    $followSw = [System.Diagnostics.Stopwatch]::StartNew()
    $started = $false
    $sessionConnected = $false

    while ($true) {
        if ($DurationSec -gt 0 -and $followSw.Elapsed.TotalSeconds -ge $DurationSec) {
            Write-Step "Runtime console follow complete (duration reached)."
            break
        }

        $client = New-Object System.Net.Sockets.TcpClient
        try {
            $connectTask = $client.ConnectAsync($HostName, $Port)
            if (-not $connectTask.Wait($NetTimeoutMs)) {
                throw "Runtime console connect timeout (${NetTimeoutMs}ms): ${HostName}:$Port"
            }

            Write-Step "Runtime console connected: ${HostName}:$Port"
            $sessionConnected = $true

            if ((-not $started) -and (-not [string]::IsNullOrWhiteSpace($StartProjectName))) {
                Write-Step "Start project: Start $StartProjectName"
                $null = Send-ConsoleCommand -Command "Start $StartProjectName" -ReadTimeoutMs $NetTimeoutMs
                $started = $true
            }

            $stream = $client.GetStream()
            $stream.ReadTimeout = 1000

            $buffer = New-Object byte[] 4096
            $carry = ""

            while ($client.Connected) {
                if ($DurationSec -gt 0 -and $followSw.Elapsed.TotalSeconds -ge $DurationSec) {
                    break
                }

                try {
                    if (-not $stream.DataAvailable) {
                        Start-Sleep -Milliseconds 100
                        continue
                    }

                    $read = $stream.Read($buffer, 0, $buffer.Length)
                    if ($read -le 0) { break }

                    $chunk = [System.Text.Encoding]::ASCII.GetString($buffer, 0, $read)
                    if ($chunk -eq "") { continue }

                    $text = ($carry + $chunk).Replace("`r", "")
                    $lines = $text -split "`n"

                    if (-not $text.EndsWith("`n")) {
                        $carry = $lines[$lines.Length - 1]
                        if ($lines.Length -gt 1) {
                            $lines = $lines[0..($lines.Length - 2)]
                        }
                        else {
                            $lines = @()
                        }
                    }
                    else {
                        $carry = ""
                    }

                    foreach ($line in $lines) {
                        $normalized = Convert-RuntimeLine -Line $line -RawMode $Raw
                        if (-not [string]::IsNullOrWhiteSpace($normalized)) {
                            if ([string]::IsNullOrWhiteSpace($Filter) -or $normalized -match $Filter) {
                                Write-Host "[RUNTIME] $normalized"
                            }
                        }
                    }
                }
                catch [System.IO.IOException] {
                    # read timeout 등은 재시도
                    continue
                }
            }
        }
        catch {
            Write-Step "Runtime console disconnected: $($_.Exception.Message)"
        }
        finally {
            if ($client.Connected) { $client.Close() }
        }

        if ($DurationSec -gt 0 -and $followSw.Elapsed.TotalSeconds -ge $DurationSec) {
            Write-Step "Runtime console follow complete (duration reached)."
            break
        }

        if ($NoReconnect) {
            Write-Step "Runtime console reconnect disabled. Ending follow session."
            break
        }

        if ($ExitOnDisconnect -and $sessionConnected) {
            Write-Step "Runtime console disconnected after a successful connection. ExitOnDisconnect enabled; ending follow session."
            break
        }

        Start-Sleep -Milliseconds $ReconnectMs
    }
}

$resolvedProjectRootDir = [System.IO.Path]::GetFullPath($ProjectRootDir)
if (-not (Test-Path -LiteralPath $resolvedProjectRootDir)) {
    throw "Project root directory not found: $resolvedProjectRootDir"
}

if ([string]::IsNullOrWhiteSpace($LocalProjectDir)) {
    $availableProjectDirs = @(Get-ChildItem -LiteralPath $resolvedProjectRootDir -Directory)

    if ([string]::IsNullOrWhiteSpace($ProjectKey)) {
        if ($availableProjectDirs.Count -eq 1) {
            $ProjectKey = $availableProjectDirs[0].Name
            Write-Step "ProjectKey not provided. Auto-selected single project: $ProjectKey"
        }
        elseif ($availableProjectDirs.Count -lt 1) {
            throw "No project folders found under: $resolvedProjectRootDir"
        }
        else {
            throw "Multiple project folders found. Specify -ProjectKey. Available: $($availableProjectDirs.Name -join ', ')"
        }
    }

    $resolvedLocalProjectDir = [System.IO.Path]::GetFullPath((Join-Path $resolvedProjectRootDir $ProjectKey))
}
else {
    $resolvedLocalProjectDir = [System.IO.Path]::GetFullPath($LocalProjectDir)
    if ([string]::IsNullOrWhiteSpace($ProjectKey)) {
        $ProjectKey = Split-Path -Path $resolvedLocalProjectDir -Leaf
    }
}

if (-not (Test-Path -LiteralPath $resolvedLocalProjectDir)) {
    throw "Local project directory not found: $resolvedLocalProjectDir"
}

$gprFiles = @(Get-ChildItem -LiteralPath $resolvedLocalProjectDir -Filter "*.gpr" -File)
if ($gprFiles.Count -lt 1) {
    throw "No .gpr file found in local project directory: $resolvedLocalProjectDir"
}
if ($gprFiles.Count -gt 1) {
    throw "Multiple .gpr files found. Specify -ProjectName explicitly. Files: $($gprFiles.Name -join ', ')"
}

$gprFile = $gprFiles[0]
$gprBaseName = [System.IO.Path]::GetFileNameWithoutExtension($gprFile.Name)

$gprDeclaredProjectName = ""
try {
    $gprText = Get-Content -LiteralPath $gprFile.FullName -Raw -Encoding UTF8
    $m = [regex]::Match($gprText, 'ProjectName\s*=\s*"([^"]+)"', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if ($m.Success) {
        $gprDeclaredProjectName = $m.Groups[1].Value.Trim()
    }
}
catch {
    # gpr 선언명 파싱 실패는 비치명으로 처리
}

$projectFolderName = Split-Path -Path $resolvedLocalProjectDir -Leaf
if ([string]::IsNullOrWhiteSpace($projectFolderName)) {
    throw "Cannot resolve project folder name from: $resolvedLocalProjectDir"
}

if ([string]::IsNullOrWhiteSpace($ProjectName)) {
    $ProjectName = $projectFolderName
}
if ([string]::IsNullOrWhiteSpace($FtpProjectDir)) {
    $FtpProjectDir = "/GPL/$projectFolderName"
}
if ([string]::IsNullOrWhiteSpace($LoadPath)) {
    $LoadPath = $FtpProjectDir
}

$FtpProjectDir = $FtpProjectDir.Replace('\\', '/').Trim()
if (-not $FtpProjectDir.StartsWith('/')) {
    $FtpProjectDir = "/$FtpProjectDir"
}

$LoadPath = $LoadPath.Replace('\\', '/').Trim()
if (-not $LoadPath.StartsWith('/')) {
    $LoadPath = "/$LoadPath"
}

$RuntimeLogPath = $RuntimeLogPath.Replace('\\', '/').Trim()
if (-not [string]::IsNullOrWhiteSpace($RuntimeLogPath)) {
    if (-not $RuntimeLogPath.StartsWith('/')) {
        $RuntimeLogPath = "/$RuntimeLogPath"
    }
}

Write-Step "Resolved project settings: LocalProjectDir=$resolvedLocalProjectDir, ProjectName=$ProjectName, FtpProjectDir=$FtpProjectDir, LoadPath=$LoadPath"
Write-Step "Resolved project selector: ProjectRootDir=$resolvedProjectRootDir, ProjectKey=$ProjectKey"
Write-Step "Resolved compile candidates seed: GprBaseName=$gprBaseName, GprDeclaredProjectName=$gprDeclaredProjectName"
Write-Step "Resolved runtime console options: FollowRuntimeConsole=$FollowRuntimeConsole, RuntimeConsolePort=$RuntimeConsolePort"
Write-Step "Resolved runtime console format options: RuntimeConsoleRaw=$RuntimeConsoleRaw, RuntimeFilter=$RuntimeFilter"
Write-Step "Resolved runtime console control options: RuntimeConsoleDurationSec=$RuntimeConsoleDurationSec, RuntimeNoReconnect=$RuntimeNoReconnect, RuntimeExitOnDisconnect=$RuntimeExitOnDisconnect"
Write-Step "Resolved runtime log options: FollowRuntimeLog=$FollowRuntimeLog, RuntimeLogPath=$RuntimeLogPath"
Write-Step "Resolved upload options: SkipUnchanged=$SkipUnchanged, VerifySize=$VerifySize"
Write-Step "Resolved debug options: DebugSnapshot=$DebugSnapshot, DebugSnapshotOnError=$DebugSnapshotOnError"

if (-not [string]::IsNullOrWhiteSpace($gprDeclaredProjectName)) {
    if ($gprDeclaredProjectName -cne $projectFolderName) {
        Write-Step "Warning: Project.gpr ProjectName ('$gprDeclaredProjectName') differs from folder name ('$projectFolderName'). Compile/Load may fail due to exact name matching."
    }
    if ($gprDeclaredProjectName -ieq $projectFolderName -and $gprDeclaredProjectName -cne $projectFolderName) {
        Write-Step "Warning: Project.gpr ProjectName and folder name differ by case only. Console commands require exact case match."
    }
}

$baseFtpUri = "ftp://$ControllerIp"

$lastKnownThread = ""
try {
    Write-Step "Controller stop: Stop -all"
    $null = Send-ConsoleCommand -Command "Stop -all" -ReadTimeoutMs $NetTimeoutMs

    if ($DebugSnapshot) {
        Invoke-DebugSnapshot -Reason "post-stop-pre-upload"
    }

    Write-Step "Uploading project folder to FTP: $FtpProjectDir"
    # curl 업로드에서 --ftp-create-dirs 사용하므로 사전 mkdir은 생략

    $files = Get-ChildItem -LiteralPath $resolvedLocalProjectDir -Recurse -File
    $uploadSw = [System.Diagnostics.Stopwatch]::StartNew()
    $uploadedCount = 0
    $skippedCount = 0
    $totalBytes = 0L
    $uploadedBytes = 0L

    $idx = 0
    foreach ($file in $files) {
        $idx = $idx + 1
        $relative = $file.FullName.Substring($resolvedLocalProjectDir.Length).TrimStart([char]'\', [char]'/')
        $relative = $relative -replace '\\', '/'

        $localSize = [long](Get-Item -LiteralPath $file.FullName).Length
        $totalBytes = $totalBytes + $localSize

        $remoteFilePath = "$FtpProjectDir/$relative"
        $skipUpload = $false
        if ($SkipUnchanged) {
            try {
                $remoteSize = [long](Get-FtpFileSize -BaseFtpUri $baseFtpUri -RemotePath $remoteFilePath -Quiet)
                if ($remoteSize -eq $localSize) {
                    $skipUpload = $true
                }
            }
            catch {
                # remote 파일이 없거나 size 조회 불가하면 업로드 진행
            }
        }

        if ($skipUpload) {
            $skippedCount = $skippedCount + 1
            Write-Step "[$idx/$($files.Count)] Skipped unchanged $relative"
            continue
        }

        Write-Step "[$idx/$($files.Count)] Uploading $relative"
        Send-FtpFile -BaseFtpUri $baseFtpUri -RemotePath $remoteFilePath -LocalPath $file.FullName
        $uploadedCount = $uploadedCount + 1
        $uploadedBytes = $uploadedBytes + $localSize

        if ($VerifySize) {
            try {
                $remoteSize = Get-FtpFileSize -BaseFtpUri $baseFtpUri -RemotePath $remoteFilePath
                if ($localSize -ne $remoteSize) {
                    throw "FTP verify failed: $relative (local=$localSize, remote=$remoteSize)"
                }
            }
            catch {
                Write-Step "Verify size skipped/fail (non-blocking): $relative"
            }
        }
    }

    $uploadSw.Stop()
    $uploadSec = [Math]::Max(0.001, $uploadSw.Elapsed.TotalSeconds)
    $uploadSpeed = $uploadedBytes / $uploadSec

    Write-Step "FTP upload summary: total=$($files.Count), uploaded=$uploadedCount, skipped=$skippedCount, bytes=$([string](Format-ByteSize $uploadedBytes))/$([string](Format-ByteSize $totalBytes)), speed=$([string](Format-ByteSize([long]$uploadSpeed)))/s"

    Write-Step "FTP upload verified: $($files.Count) files"

    $compileCandidates = New-Object System.Collections.Generic.List[string]
    foreach ($name in @($ProjectName, $gprDeclaredProjectName, $projectFolderName, $gprBaseName)) {
        if (-not [string]::IsNullOrWhiteSpace($name)) {
            if (-not $compileCandidates.Contains($name)) {
                [void]$compileCandidates.Add($name)
            }
        }
    }
    Write-Step "Compile candidate order: $($compileCandidates -join ', ')"

    $compiledName = $null
    $compileErrors = New-Object System.Collections.Generic.List[string]
    foreach ($candidate in $compileCandidates) {
        Write-Step "Compile project: Compile $candidate"
        try {
            $null = Send-ConsoleCommand -Command "Compile $candidate" -ReadTimeoutMs $NetTimeoutMs
            $compiledName = $candidate
            break
        }
        catch {
            $compileErr = $_.Exception.Message
            [void]$compileErrors.Add("$candidate => $compileErr")

            if ($compileErr -match "-508" -or $compileErr -match "-743") {
                Write-Step "Compile failed for '$candidate' (missing/invalid). Try Load then retry."
                try {
                    $null = Send-ConsoleCommand -Command "Load $LoadPath" -ReadTimeoutMs $NetTimeoutMs
                    $null = Send-ConsoleCommand -Command "Compile $candidate" -ReadTimeoutMs $NetTimeoutMs
                    $compiledName = $candidate
                    break
                }
                catch {
                    [void]$compileErrors.Add("$candidate (after Load) => $($_.Exception.Message)")
                }
            }
        }
    }

    if ($null -eq $compiledName) {
        throw "All compile candidates failed: $($compileErrors -join ' || ')"
    }
    else {
        Write-Step "Compile success with project name: $compiledName"
        $ProjectName = $compiledName
    }

    if ($DebugSnapshot) {
        Invoke-DebugSnapshot -Reason "post-compile-pre-start"
    }

    if (-not $SkipStart) {
        if ($FollowRuntimeConsole) {
            $lastKnownThread = $ProjectName
            Watch-RuntimeConsole -HostName $ControllerIp -Port $RuntimeConsolePort -ReconnectMs $RuntimeReconnectMs -StartProjectName $ProjectName -Raw ([bool]$RuntimeConsoleRaw) -Filter $RuntimeFilter -DurationSec $RuntimeConsoleDurationSec -NoReconnect ([bool]$RuntimeNoReconnect) -ExitOnDisconnect ([bool]$RuntimeExitOnDisconnect)
        }
        elseif ($FollowRuntimeLog) {
            Write-Step "Start project: Start $ProjectName"
            $lastKnownThread = $ProjectName
            $null = Send-ConsoleCommand -Command "Start $ProjectName" -ReadTimeoutMs $NetTimeoutMs
            Watch-RuntimeLog -BaseFtpUri $baseFtpUri -RemotePath $RuntimeLogPath -DurationSec $FollowDurationSec -IntervalMs $FollowIntervalMs
        }
        else {
            Write-Step "Start project: Start $ProjectName"
            $lastKnownThread = $ProjectName
            $null = Send-ConsoleCommand -Command "Start $ProjectName" -ReadTimeoutMs $NetTimeoutMs
        }
    }

    Write-Step "Check error log"
    $null = Send-ConsoleCommand -Command "ErrorLog" -ReadTimeoutMs $NetTimeoutMs

    if ($DebugSnapshot) {
        Invoke-DebugSnapshot -ThreadName $lastKnownThread -Reason "post-run"
    }

    Write-Step "Done"
}
catch {
    if ($DebugSnapshotOnError) {
        Invoke-DebugSnapshot -ThreadName $lastKnownThread -Reason "on-error"
    }
    throw
}
