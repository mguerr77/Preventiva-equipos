########################################################################################################
# DESCRIPCIÓN
# Script autocontenido de generación de reporte KB e instalación de actualizaciones.    
# Diseñado para ejecutarse desde una herramienta de gestión centralizada en equipos remotos.
#     1) Genera el reporte de actualizaciones si no existe.
#     2) Comprueba e instala PSWindowsUpdate si hace falta.
#     3) Lee los KB del reporte anterior y los instala.
#     
# Todos los archivos se almacenan en C:\preventiva (o en la raíz de la unidad de sistema actual).
# El script es completamente autocontenido y no depende de otros scripts.
########################################################################################################

param(
    [string]$ReportePath = ""
)

# Validar permisos administrativos
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: Este script debe ejecutarse con permisos administrativos." -ForegroundColor Red
    exit 1
}




function Get-PreventivaRoot {
    $rutaBase = "$env:SystemDrive\preventiva"
    
    if (-not (Test-Path $rutaBase)) {
        try {
            New-Item -ItemType Directory -Path $rutaBase -Force -ErrorAction Stop | Out-Null
            Write-Host "Carpeta de trabajo creada: $rutaBase" -ForegroundColor DarkGray
        } catch {
            Write-Host "ERROR: No se pudo crear la carpeta $rutaBase : $_" -ForegroundColor Red
            exit 1
        }
    }

    return $rutaBase
}

function Invoke-GenerarReporteActualizaciones {
    $root = Get-PreventivaRoot
    $nombrePC = $env:COMPUTERNAME
    $reporteArchivo = "$root\Reporte_Sistema_y_Actualizaciones-v0.4-$nombrePC.txt"

    Write-Host "Generando reporte de actualizaciones..." -ForegroundColor Cyan

    # 1. Obtener versión del Sistema Operativo
    $OS = Get-CimInstance -ClassName Win32_OperatingSystem
    $OSInfo = @"
==================================================
INFORMACIÓN DEL SISTEMA OPERATIVO
==================================================
Producto:          $($OS.Caption)
Versión:           $($OS.Version)
Compilación (Build): $($OS.BuildNumber)
Arquitectura:      $($OS.OSArchitecture)
==================================================
"@

    # 2. Obtener historial completo de actualizaciones usando la API de Windows Update
    Write-Host "Buscando fallos y errores de parches KB..." -ForegroundColor DarkGray

    # Forzar relanzamiento en PowerShell de 64 bits si Symantec lo ejecuta en 32 bits
    if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
        $PowerShell64 = "$env:SYSTEMROOT\SysNative\WindowsPowerShell\v1.0\powershell.exe"
        if (Test-Path $PowerShell64) {
            & $PowerShell64 -NoProfile -ExecutionPolicy Bypass -File "$PSCommandPath"
            exit $LASTEXITCODE
        }
    }

        
    $UpdateSession = New-Object -ComObject Microsoft.Update.Session
    $UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
    $TotalHistoryCount = $UpdateSearcher.GetTotalHistoryCount()

    $UpdateHistory = @()
    if ($TotalHistoryCount -gt 0) {
        $HistoryResults = $UpdateSearcher.QueryHistory(0, $TotalHistoryCount)
        
        $UpdateHistory = foreach ($Result in $HistoryResults) {
            # Traducir los códigos de resultado de la API nativa
            $Status = switch ($Result.ResultCode) {
                0 { "Incompleto" }
                1 { "En progreso" }
                2 { "Instalado con éxito" }
                3 { "Instalado con errores (Incidencia)" }
                4 { "Fallido (Incidencia)" }
                5 { "Abortado" }
                Default { "Desconocido" }
            }

            # Formatear el código de error HRESULT si falló (en formato hexadecimal)
            $ErrorCode = "0x{0:X8}" -f $Result.HResult
            if ($Result.ResultCode -eq 2) { $ErrorCode = "Ninguno" }

            # Extraer el código KB si existe
            $KbMatch = [regex]::Match($Result.Title, "(KB\d{6,8})")
            $KBNumber = if ($KbMatch.Success) { $KbMatch.Value } else { "No aplica" }

            [PSCustomObject]@{
                Fecha       = $Result.Date
                Estado      = $Status
                CódigoError = $ErrorCode
                KB          = $KBNumber
                Título      = $Result.Title
            }
        }
    }

    # 3. Formatear el reporte final (Aplicando el filtro estricto y evitando duplicados)
    $ReportHeader = @"

==================================================
ALERTAS: ACTUALIZACIONES KB CON ERRORES O FALLIDAS
==================================================
"@

    $FinalReport = New-Object System.Text.StringBuilder
    [void]$FinalReport.AppendLine($OSInfo)
    [void]$FinalReport.AppendLine($ReportHeader)

    $ErroresEncontrados = 0
    $KBReportados = New-Object System.Collections.Generic.HashSet[string]

    if ($UpdateHistory.Count -gt 0) {
        foreach ($Update in ($UpdateHistory | Sort-Object Fecha -Descending)) {
            $kbActual = $Update.KB

            # FILTRO: El estado debe ser un error/fallo, el ID debe ser un KB real y no repetido
            if ($Update.Estado -ne "Instalado con éxito" -and $kbActual -ne "No aplica" -and $KBReportados.Add($kbActual)) {
                [void]$FinalReport.AppendLine("Fecha:   $($Update.Fecha)")
                [void]$FinalReport.AppendLine("Estado:  $($Update.Estado)")
                [void]$FinalReport.AppendLine("Error:   $($Update.CódigoError)")
                [void]$FinalReport.AppendLine("ID KB:   $($Update.KB)")
                [void]$FinalReport.AppendLine("Parche:  $($Update.Título)")
                [void]$FinalReport.AppendLine("-" * 50)
                $ErroresEncontrados++
            }
        }
    }

    # Si no hay errores, registrar que el equipo está limpio
    if ($ErroresEncontrados -eq 0) {
        [void]$FinalReport.AppendLine("¡Buenas noticias! No se encontraron parches KB con errores o estados fallidos.")
    }

    # 4. Guardar en el archivo de texto
    try {
        $FinalReport.ToString() | Out-File -FilePath $reporteArchivo -Encoding UTF8 -ErrorAction Stop
        Write-Host "Reporte generado: $reporteArchivo" -ForegroundColor Green
        return $reporteArchivo
    } catch {
        Write-Host "ERROR: No se pudo guardar el reporte: $_" -ForegroundColor Red
        return $null
    }
}

function Get-ListaKBDesdeReporte {
    param([string]$RutaReporte)

    if (-not $RutaReporte -or -not (Test-Path $RutaReporte -PathType Leaf)) {
        return @()
    }

    $contenido = Get-Content -Path $RutaReporte -Raw
    $kbMatches = [regex]::Matches($contenido, 'KB\d{6,8}')
    $lista = @()

    foreach ($match in $kbMatches) {
        $kb = $match.Value.ToUpper()
        if ($kb -notin $lista) {
            $lista += $kb
        }
    }

    return $lista
}

function Ensure-PSWindowsUpdateInstalled {
    if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        Write-Host "PSWindowsUpdate no está instalado. Instalando dependencias..." -ForegroundColor Yellow
        try {
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false -ErrorAction Stop | Out-Null
            Install-Module -Name PSWindowsUpdate -Force -Confirm:$false -ErrorAction Stop
            Write-Host "PSWindowsUpdate instalado correctamente." -ForegroundColor Green
        } catch {
            Write-Host "ERROR: No se pudo instalar PSWindowsUpdate: $_" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "PSWindowsUpdate ya está disponible." -ForegroundColor Green
    }
}

# ========================================
# FLUJO PRINCIPAL
# ========================================
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  REPORTE E INSTALACIÓN DE ACTUALIZACIONES KB" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

# Determinar ruta del reporte
if (-not [string]::IsNullOrWhiteSpace($ReportePath)) {
    $rutaReporte = $ReportePath
} else {
    $root = Get-PreventivaRoot
    $nombrePC = $env:COMPUTERNAME
    $rutaReporteEsperada = "$root\Reporte_Sistema_y_Actualizaciones-v0.4-$nombrePC.txt"
    
    if ((Test-Path $rutaReporteEsperada)) {
        $rutaReporte = $rutaReporteEsperada
    } else {
        $rutaReporte = Invoke-GenerarReporteActualizaciones
    }
}

# Si aún no hay reporte, pedir al usuario
if (-not $rutaReporte) {
    Write-Host "Introduce la ruta del reporte de actualizaciones manualmente:" -ForegroundColor Yellow
    $rutaReporte = Read-Host "Ruta completa del archivo .txt"
}

# Validar que el reporte existe
if (-not (Test-Path $rutaReporte -PathType Leaf)) {
    Write-Host "ERROR: No se encontró el archivo del reporte: $rutaReporte" -ForegroundColor Red
    exit 1
}

Write-Host "Reporte utilizado: $rutaReporte" -ForegroundColor Green
Write-Host ""

# Extraer lista de KB del reporte
$ListaKBs = Get-ListaKBDesdeReporte -RutaReporte $rutaReporte

if ($ListaKBs.Count -eq 0) {
    Write-Host "No se detectaron KB en el reporte. No hay nada que instalar." -ForegroundColor Yellow
    exit 0
}

Write-Host "KB detectados para instalar: $($ListaKBs -join ', ')" -ForegroundColor Cyan
Write-Host ""

# Asegurar que PSWindowsUpdate está instalado
Ensure-PSWindowsUpdateInstalled
Write-Host ""

# Instalar las actualizaciones
Write-Host "Iniciando instalación de actualizaciones..." -ForegroundColor Yellow
try {
    Get-WindowsUpdate -KBArticleID $ListaKBs -Install -AcceptAll #-AutoReboot
    Write-Host "Proceso de instalación completado." -ForegroundColor Green
} catch {
    Write-Host "ERROR durante la instalación: $_" -ForegroundColor Red
    exit 1
}