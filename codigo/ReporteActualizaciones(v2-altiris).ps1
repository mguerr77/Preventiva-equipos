

# ====================================================================================================
# Script: ReporteActualizaciones(v2-altiris).ps1
# Descripción: Genera un reporte de actualizaciones KB con errores o fallidas en el
# sistema operativo Windows. Este script es una versión mejorada del original, 
# con soporte para evitar repeticiones de KB en el reporte final.
# ====================================================================================================

# DETECTAR RUTA LOCAL
# Crear carpeta si no existe para almacenar localmente el reporte

if (!(Test-Path (Join-Path $env:SystemDrive '\preventiva'))) 
{
    New-Item -ItemType Directory -Path (Join-Path $env:SystemDrive '\preventiva') -Force | Out-Null
}    

$rutaBase = [System.IO.Path]::GetFullPath((Join-Path $env:SystemDrive '\preventiva'))

# Nombre archivo = nombre PC
$nombrePC = $env:COMPUTERNAME

# Configuración del archivo de salida
$OutputFile = "$rutaBase\Reporte_Sistema_y_Actualizaciones-v0.3-$nombrePC.txt"

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

$UpdateSession = New-Object -ComObject Microsoft.Update.Session
$UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
$TotalHistoryCount = $UpdateSearcher.GetTotalHistoryCount()

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
} else {
    $UpdateHistory = "No se encontró historial de actualizaciones disponible."
}

# 3. Formatear el reporte final (Aplicando el filtro estricto)
$ReportHeader = @"

==================================================
ALERTAS: ACTUALIZACIONES KB CON ERRORES O FALLIDAS
==================================================
"@

$FinalReport = New-Object System.Text.StringBuilder
[void]$FinalReport.AppendLine($OSInfo)
[void]$FinalReport.AppendLine($ReportHeader)

$ErroresEncontrados = 0
# Evitar repeticiones de KB en el reporte final usando un HashSet
$KBReportados = New-Object System.Collections.Generic.HashSet[string]

if ($UpdateHistory -is [array]) {
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

# Si recorrió todo y el contador es 0, registrar que el equipo está limpio
if ($ErroresEncontrados -eq 0) {
    [void]$FinalReport.AppendLine("¡Buenas noticias! No se encontraron parches KB con errores o estados fallidos.")
}

# 4. Guardar en el archivo de texto
$FinalReport.ToString() | Out-File -FilePath $OutputFile -Encoding utf8

