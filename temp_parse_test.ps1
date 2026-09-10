try {
    $s = Get-Content -LiteralPath 'd:\Preventiva equipos\Codigo\Reporte_y_Instalar_Actualizaciones.ps1' -Raw -Encoding UTF8
    [ScriptBlock]::Create($s) | Out-Null
    Write-Output 'PARSE_OK'
} catch {
    Write-Output 'PARSE_ERROR'
    Write-Output $_.Exception.ToString()
    exit 1
}
