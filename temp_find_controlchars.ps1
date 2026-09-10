$s = Get-Content -LiteralPath 'd:\Preventiva equipos\Codigo\Reporte_y_Instalar_Actualizaciones.ps1' -Raw -Encoding UTF8
$bad = @()
for ($i=0; $i -lt $s.Length; $i++) {
    $code = [int][char]$s[$i]
    if ($code -lt 32 -and $code -ne 9 -and $code -ne 10 -and $code -ne 13) { $bad += @{pos=($i+1); code=$code; char=[char]$s[$i]} }
}
if ($bad.Count -eq 0) { Write-Output 'NO_CONTROL_CHARS' } else { $bad | ForEach-Object { Write-Output "pos=$($_.pos) code=$($_.code) char=[{0}]" -f $_.char } }
