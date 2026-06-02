$ip = '192.168.0.2'; $port = 1403
Write-Host '[1403] Connecting...'
try {
    $c = New-Object System.Net.Sockets.TcpClient
    $c.Connect($ip, $port)
    Write-Host "[1403] Connected. Reading for 10 seconds..."
    $st = $c.GetStream(); $st.ReadTimeout = 1000
    $total = 0
    $start = Get-Date
    while (((Get-Date) - $start).TotalSeconds -lt 10) {
        try {
            $buf = New-Object byte[] 4096
            $r = $st.Read($buf, 0, $buf.Length)
            if ($r -gt 0) {
                $chunk = [System.Text.Encoding]::ASCII.GetString($buf, 0, $r)
                $total += $r
                Write-Host -NoNewline $chunk
            }
        } catch [System.IO.IOException] { }
    }
    $c.Close()
    Write-Host "`n[1403] Done. Total bytes: $total"
} catch {
    Write-Host "[1403] Error: $_"
}
