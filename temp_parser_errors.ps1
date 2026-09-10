Add-Type -AssemblyName System.Management.Automation
$code = Get-Content -LiteralPath 'd:\Preventiva equipos\Codigo\Reporte_y_Instalar_Actualizaciones.ps1' -Raw -Encoding UTF8
$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseInput($code, [ref]$tokens, [ref]$errors)
if ($errors) {
    foreach ($e in $errors) {
        Write-Output "Error: $($e.Message) at Line $($e.Extent.StartLineNumber) Col $($e.Extent.StartColumn)"
    }
} else { Write-Output 'No parser errors reported.' }
