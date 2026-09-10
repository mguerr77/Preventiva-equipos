$lines = Get-Content -LiteralPath 'd:\Preventiva equipos\Codigo\Reporte_y_Instalar_Actualizaciones.ps1' -Raw -Encoding UTF8 -ErrorAction Stop
$arr = $lines -split "\r?\n"
$cum = 0
for ($i=0; $i -lt $arr.Length; $i++) {
    $line = $arr[$i]
    $count = ($line.ToCharArray() | Where-Object { $_ -eq '"' }).Count
    $cum += $count
    $parity = if ($cum % 2 -eq 0) { 'even' } else { 'odd' }
    if ($count -gt 0) {
        Write-Output ("Line {0,3}: quotes={1,2} cum={2,3} parity={3}  -> {4}" -f ($i+1), $count, $cum, $parity, $line)
    }
}
if ($cum % 2 -ne 0) { Write-Output "UNMATCHED total quotes: $cum" } else { Write-Output "All quotes matched (total $cum)" }
