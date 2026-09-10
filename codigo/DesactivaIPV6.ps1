# 1. VALIDACIÓN EXTRICTA DE PRIVILEGIOS DE ADMINISTRADOR
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "=========================================================" -ForegroundColor Red
    Write-Host "[X] ERROR: Este script DEBE ejecutarse como Administrador." -ForegroundColor Red
    Write-Host "Por favor, cierra esta ventana, haz clic derecho sobre" -ForegroundColor Red
    Write-Host "PowerShell y selecciona 'Ejecutar como administrador'." -ForegroundColor Red
    Write-Host "=========================================================" -ForegroundColor Red
    Exit
}

# Variable para rastrear si algo falla en el camino
$ScriptError = $false

# 2. MOSTRAR EL ESTADO INICIAL
Write-Host "=== ESTADO INICIAL DE IPV6 EN LOS ADAPTADORES ===" -ForegroundColor Cyan
Get-NetAdapterBinding -ComponentID ms_tcpip6 | Select-Object Name, ComponentID, Enabled
Write-Host ""

# 3. INTENTAR DESACTIVAR IPV6 EN ADAPTADORES
try {
    Write-Host "Desactivando IPv6 en todos los adaptadores de red..." -ForegroundColor Yellow
    # Forzamos que cualquier fallo detenga el bloque con -ErrorAction Stop
    Disable-NetAdapterBinding -Name "*" -ComponentID ms_tcpip6 -Confirm:$false -ErrorAction Stop
    Write-Host "Adaptadores modificados." -ForegroundColor Green
} catch {
    Write-Host "ERROR al modificar los adaptadores: $_" -ForegroundColor Red
    $ScriptError = $true
}

# 4. INTENTAR DESACTIVAR IPV6 EN EL REGISTRO
$RegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters"
$ValueName = "DisabledComponents"
$ValueData = 255

try {
    Write-Host "Aplicando restricción total de IPv6 en el Registro de Windows..." -ForegroundColor Yellow
    if (-not (Test-Path $RegPath)) {
        New-Item -Path $RegPath -Force -ErrorAction Stop | Out-Null
    }
    New-ItemProperty -Path $RegPath -Name $ValueName -Value $ValueData -PropertyType DWORD -Force -ErrorAction Stop | Out-Null
    Write-Host "Registro modificado" -ForegroundColor Green
} catch {
    Write-Host "ERROR al modificar el registro del sistema: $_" -ForegroundColor Red
    $ScriptError = $true
}

# 5. VERIFICACIÓN REAL DEL RESULTADO
Write-Host ""
Write-Host "=== AUDITORÍA FINAL DE LA CONFIGURACIÓN ===" -ForegroundColor Cyan

# Consultamos de verdad cómo han quedado los adaptadores y el registro
$AdaptadoresActivos = Get-NetAdapterBinding -ComponentID ms_tcpip6 | Where-Object {$_.Enabled -eq $true}
$ValorRegistroActual = (Get-ItemProperty -Path $RegPath -Name $ValueName -ErrorAction SilentlyContinue).DisabledComponents

# Evaluamos si todo está realmente como debería
if ($AdaptadoresActivos.Count -eq 0 -and $ValorRegistroActual -eq 255 -and $ScriptError -eq $false) {
    Write-Host "CONFIGURACIÓN APLICADA CON ÉXITO" -ForegroundColor Green
    Write-Host "ATENCIÓN: Es obligatorio reiniciar el equipo para que Windows aplique la baja de IPv6 en el sistema." -ForegroundColor Magenta
} else {
    Write-Host "EL PROCESO HA FALLADO o quedó incompleto." -ForegroundColor Red
    if ($AdaptadoresActivos.Count -gt 0) {
        Write-Host "  - Alerta: Aún quedan adaptadores con IPv6 activo." -ForegroundColor Red
    }
    if ($ValorRegistroActual -ne 255) {
        Write-Host "  - Alerta: La clave del registro no se estableció en 255." -ForegroundColor Red
    }
}
Write-Host ""