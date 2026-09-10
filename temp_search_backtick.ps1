$s = Get-Content -LiteralPath 'd:\Preventiva equipos\Codigo\Reporte_y_Instalar_Actualizaciones.ps1' -Raw -Encoding UTF8
$found = $false
for ($i=0; $i -lt $s.Length; $i++) {
    if ([int][char]$s[$i] -eq 96) { $found = $true; Write-Output ("Found backtick at position {0}" -f ($i+1)) }
}
if (-not $found) { Write-Output 'NO_BACKTICK' }
