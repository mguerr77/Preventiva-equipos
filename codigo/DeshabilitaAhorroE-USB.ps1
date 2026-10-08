# DeshabilitaAhorroE-USB.ps1
# Desactiva la desconexión de puertos USB en el perfil de energía activo de Windows 11
# para prevenir desconexiones no deseadas de dispositivos USB

# Validar permisos elevados
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: Este script requiere permisos de administrador." -ForegroundColor Red
    pause
    exit 1
}

Write-Host "Deshabilitando ahorro de energía en puertos USB..." -ForegroundColor Cyan

try {
    # Obtener el perfil de energía activo
    $powerScheme = powercfg /getactivescheme
    if ($powerScheme -match '([a-f0-9\-]{36})') {
        $schemeGUID = $matches[1]
        Write-Host "Perfil activo: $schemeGUID" -ForegroundColor Yellow
    }
    else {
        throw "No se pudo obtener el perfil de energía activo"
    }

    # Subgrupo de configuración USB: 2a737441-1930-4856-bc48-b90f7b148480
    $usbSubgroupGUID = "2a737441-1930-4856-bc48-b90f7b148480"
    
    # Configuración de suspensión selectiva USB: 48e6b7a6-50f5-41d7-9146-5859641c6a2f
    $usbSettingGUID = "48e6b7a6-50f5-41d7-9146-5859641c6a2f"

    # Desactivar suspensión selectiva USB (AC - corriente alterna)
    Write-Host "Desactivando suspensión USB en alimentación AC..." -ForegroundColor White
    powercfg /set $schemeGUID $usbSubgroupGUID $usbSettingGUID 0

    # Desactivar suspensión selectiva USB (DC - batería)
    Write-Host "Desactivando suspensión USB en alimentación DC..." -ForegroundColor White
    powercfg /setdcindex $schemeGUID $usbSubgroupGUID $usbSettingGUID 0

    Write-Host "`n✓ Configuración completada exitosamente" -ForegroundColor Green
    Write-Host "Los puertos USB no se desconectarán por ahorro de energía" -ForegroundColor Green
}
catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
    pause
    exit 1
}

pause