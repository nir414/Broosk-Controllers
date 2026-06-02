param(
    [string]$HostIp  = '192.168.0.2',
    [int]   $Port    = 1402,
    [string]$Command = 'Show Thread',
    [int]   $TimeoutMs = 8000,
    [int]   $IdleMs    = 400
)

$client = [System.Net.Sockets.TcpClient]::new()
try {
    $client.ReceiveTimeout = $TimeoutMs
    $client.SendTimeout    = 4000
    $client.Connect($HostIp, $Port)
    $stream = $client.GetStream()

    $payload = $Command + "`r`n"
    $bytes   = [System.Text.Encoding]::ASCII.GetBytes($payload)
    $stream.Write($bytes, 0, $bytes.Length)
    $stream.Flush()

    $buffer = New-Object byte[] 16384
    $sb     = [System.Text.StringBuilder]::new()
    $deadline   = (Get-Date).AddMilliseconds($TimeoutMs)
    $idleUntil  = (Get-Date).AddMilliseconds($IdleMs)
    $statusEnd  = [char]60 + '/STATUS' + [char]62

    while ((Get-Date) -lt $deadline) {
        if ($stream.DataAvailable) {
            $n = $stream.Read($buffer, 0, $buffer.Length)
            if ($n -le 0) { break }
            [void]$sb.Append([System.Text.Encoding]::ASCII.GetString($buffer, 0, $n))
            $idleUntil = (Get-Date).AddMilliseconds($IdleMs)
            if ($sb.ToString().Contains($statusEnd)) { break }
        } elseif ((Get-Date) -gt $idleUntil -and $sb.Length -gt 0) {
            break
        } else {
            Start-Sleep -Milliseconds 50
        }
    }
    Write-Output $sb.ToString()
} finally {
    if ($client.Connected) { $client.Close() }
}
