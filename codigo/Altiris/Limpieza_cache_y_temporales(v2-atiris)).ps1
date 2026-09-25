<#
.SYNOPSIS
    Script de limpieza segura para Windows 11 Pro.
    Limpia temporales de sistema, usuarios y ejecuta optimización nativa.
#>
<#
.SYNOPSIS
    Script avanzado de higienización y optimización para Windows 11 Pro en entornos de dominio.
    Requiere privilegios de Administrador 
#>

# Verificación de privilegios de elevación (Administrador)
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Se requieren privilegios administrativos elevados para ejecutar este script."
    Exit
}

# 1. Purgado de la Papelera de Reciclaje de todos los usuarios del sistema
Write-Host "--- Depurando la Papelera de Reciclaje global ($Recycle.Bin) ---" -ForegroundColor Cyan
$RecycleBinPath = "C:\`$Recycle.Bin"
if (Test-Path $RecycleBinPath) {
    # Eliminamos el contenido de los SID de usuario manteniendo la estructura base si está bloqueada
    Get-ChildItem -Path $RecycleBinPath -Recurse -Force -ErrorAction SilentlyContinue | 
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}

# 2. Limpieza de carpetas temporales del Sistema y Volcados de Memoria (Dumps)
Write-Host "`n--- Eliminando archivos temporales y volcados de error del sistema ---" -ForegroundColor Cyan
$RutasSistema = @(
    "C:\Windows\Temp",
    "C:\Windows\Minidump",
    "C:\Windows\MEMORY.DMP"
)

foreach ($Ruta in $RutasSistema) {
    if (Test-Path $Ruta) {
        Write-Host "Procesando ruta de sistema: $Ruta" -ForegroundColor Gray
        Get-ChildItem -Path $Ruta -Recurse -Force -ErrorAction SilentlyContinue | 
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# 3. Iteración sobre perfiles de usuario (Temporales de AppData y CrashDumps)
Write-Host "`n--- Limpiando perfiles de usuario en C:\Users ---" -ForegroundColor Cyan
$PerfilesUsuarios = Get-ChildItem -Path "C:\Users" -Directory

foreach ($Perfil in $PerfilesUsuarios) {
    # Excluir perfiles especiales del sistema para evitar corrupción de entorno
    if ($Perfil.Name -notmatch "Public|All Users|Default User|desktop.ini") {
        Write-Host "Optimizando perfil: $($Perfil.Name)" -ForegroundColor Gray
        
        # Definición de subrutas críticas por perfil
        $RutasPerfil = @(
            (Join-Path $Perfil.FullName "AppData\Local\Temp"),
            (Join-Path $Perfil.FullName "AppData\Local\CrashDumps"),
            (Join-Path $Perfil.FullName "AppData\Local\Microsoft\Windows\INetCache"),
            (Join-Path $Perfil.FullName "AppData\Local\Google\Chrome\User Data\Default\Code Cache"),
            (Join-Path $Perfil.FullName "AppData\Local\Google\Chrome\User Data\Default\Cache"),
            (Join-Path $Perfil.FullName "AppData\Local\Microsoft\Edge\User Data\Default\Cache"),
            (Join-Path $Perfil.FullName "AppData\Local\Microsoft\Edge\User Data\Default\Code Cache"),
            (Join-Path $Perfil.FullName "AppData\Local\Microsoft\Edge\User Data\component_crx_cache")
            (Join-Path $Perfil.FullName "AppData\Local\Mozilla\Firefox\Profiles")
        )
        
        foreach ($SubRuta in $RutasPerfil) {
            if (Test-Path $SubRuta) {
                Get-ChildItem -Path $SubRuta -Recurse -Force -ErrorAction SilentlyContinue | 
                    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

# 4. Optimización de la caché del Servicio de Actualizaciones (Windows Update)
Write-Host "`n--- Deteniendo servicios e higienizando el almacenamiento de Windows Update ---" -ForegroundColor Cyan
# Detener servicios dependientes para liberar bloqueos de archivos
Stop-Service -Name "bits" -Force -ErrorAction SilentlyContinue
Stop-Service -Name "wuauserv" -Force -ErrorAction SilentlyContinue

$SoftwareDistDownload = "C:\Windows\SoftwareDistribution\Download"
if (Test-Path $SoftwareDistDownload) {
    Get-ChildItem -Path $SoftwareDistDownload -Recurse -Force -ErrorAction SilentlyContinue | 
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}

# Restablecer el estado operacional de los servicios
Start-Service -Name "wuauserv" -ErrorAction SilentlyContinue

# 5. Automatización del Liberador de Espacio Nativo (Cleanmgr) vía Registro
Write-Host "`n--- Lanzando el Liberador de Espacio en Disco nativo (Cleanmgr) ---" -ForegroundColor Cyan
$StateFlagsKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
$StateFlagsNumber = "65535" # Identificador aleatorio para la configuración automatizada

# Forzar en el registro que todas las categorías de limpieza se seleccionen para el StateFlags65535
if (Test-Path $StateFlagsKey) {
    $SubClaves = Get-ChildItem -Path $StateFlagsKey -Name
    foreach ($SubClave in $SubClaves) {
        New-ItemProperty -Path "$StateFlagsKey\$SubClave" -Name "StateFlags$StateFlagsNumber" -Value 2 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
    }
    # Invocación silenciosa del proceso nativo utilizando la automatización preconfigurada
    Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/sagerun:$StateFlagsNumber" -NoNewWindow -Wait
}

# 6. Mantenimiento del Almacenamiento de Componentes (DISM)
Write-Host "`n--- Ejecutando consolidación del almacén de componentes (DISM) ---" -ForegroundColor Cyan
# Remueve las versiones anteriores de los componentes actualizados (operación irreversible pero segura)
DISM.exe /Online /Cleanup-Image /StartComponentCleanup /ResetBase

Write-Host "`nPROCESO FINALIZADO CORRECTAMENTE" -ForegroundColor Green
