<#
.SYNOPSIS
    Script de limpieza segura para Windows 11 Pro.
    Limpia temporales de sistema, usuarios y ejecuta optimización nativa.
#>

# 1. Limpieza de carpetas temporales del Sistema
Write-Host "--- Limpiando archivos temporales del sistema ---" -ForegroundColor Cyan
$TempSistema = "C:\Windows\Temp"
if (Test-Path $TempSistema) {
    Get-ChildItem -Path $TempSistema -Recurse -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}

# 2. Limpieza de carpetas temporales de TODOS los usuarios
Write-Host "`n--- Limpiando archivos temporales de usuarios ---" -ForegroundColor Cyan
$RutasUsuarios = Get-ChildItem -Path "C:\Users" -Directory
foreach ($Usuario in $RutasUsuarios) {
    $TempUsuario = Join-Path $Usuario.FullName "AppData\Local\Temp"
    if (Test-Path $TempUsuario) {
        Write-Host "Limpiando temporales de: $($Usuario.Name)" -ForegroundColor Gray
        Get-ChildItem -Path $TempUsuario -Recurse -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# 3. Limpieza de caché de Windows Update (Segura si el servicio está detenido)
Write-Host "`n--- Limpiando caché de Windows Update (SoftwareDistribution) ---" -ForegroundColor Cyan
Stop-Service -Name "wuauserv" -Force -ErrorAction SilentlyContinue
$SoftwareDist = "C:\Windows\SoftwareDistribution\Download"
if (Test-Path $SoftwareDist) {
    Get-ChildItem -Path $SoftwareDist -Recurse -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}
Start-Service -Name "wuauserv" -ErrorAction SilentlyContinue

# 4. Ejecución del Liberador de espacio nativo (Configuración automática)
Write-Host "`n--- Ejecutando optimización nativa de Windows (DISM) ---" -ForegroundColor Cyan
# Limpia archivos reemplazados por actualizaciones antiguas de Windows
DISM.exe /Online /Cleanup-Image /StartComponentCleanup

Write-Host "`n¡Limpieza segura completada con éxito!" -ForegroundColor Green