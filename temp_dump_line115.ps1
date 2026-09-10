$lines = Get-Content -LiteralPath 'd:\Preventiva equipos\Codigo\Reporte_y_Instalar_Actualizaciones.ps1' -Raw -Encoding UTF8
$arr = $lines -split "\r?\n"
$line115 = $arr[114]
Write-Output "Line115: [$line115]"
for ($i=0; $i -lt $line115.Length; $i++) {
    $ch = $line115[$i]
    $code = [int][char]$ch
    $hex = '{0:X4}' -f $code
    Write-Output ("{0,3}: '{1}' (U+{2})" -f ($i+1), $ch, $hex)
}
