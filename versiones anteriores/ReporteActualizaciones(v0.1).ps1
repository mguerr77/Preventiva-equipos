# =========================
# DETECTAR USB
# =========================
$usb = Get-Volume | Where-Object { $_.FileSystemLabel -eq 'KINGSTON' }

if (!$usb) {
    Write-Host 'ERROR: No se ha encontrado el pendrive.'
    exit
}

$rutaBase = "$($usb.DriveLetter):\preventiva"

# Crear carpeta si no existe
if (!(Test-Path $rutaBase)) {
    New-Item -ItemType Directory -Path $rutaBase | Out-Null
}

# Nombre archivo = nombre PC
$nombrePC = $env:COMPUTERNAME
#$ruta = "$rutaBase\$nombrePC.txt"



# Configuración del archivo de salida




$OutputFile = "$rutaBase\Reporte_Sistema_y_Actualizaciones-$nombrePC.txt"



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
# Esto extraerá parches críticos, de seguridad, controladores y sus incidencias.
Write-Host "Consultando el historial de Windows Update (esto puede tardar unos segundos)..." -ForegroundColor Cyan

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

        [PSCustomObject]@{
            Fecha       = $Result.Date
            Estado      = $Status
            CódigoError = $ErrorCode
            Título      = $Result.Title
        }
    }
} else {
    $UpdateHistory = "No se encontró historial de actualizaciones disponible."
}

# 3. Formatear el reporte final
$ReportHeader = @"

==================================================
HISTORIAL DE ACTUALIZACIONES E INCIDENCIAS
==================================================
"@

# Unificar todo el contenido en una cadena de texto transparente
$FinalReport = New-Object System.Text.StringBuilder
[void]$FinalReport.AppendLine($OSInfo)
[void]$FinalReport.AppendLine($ReportHeader)

if ($UpdateHistory -is [array]) {
    # Ordenar por fecha más reciente primero y estructurar como lista legible
    foreach ($Update in ($UpdateHistory | Sort-Object Fecha -Descending)) {
        [void]$FinalReport.AppendLine("Fecha:   $($Update.Fecha)")
        [void]$FinalReport.AppendLine("Estado:  $($Update.Estado)")
        [void]$FinalReport.AppendLine("Error:   $($Update.CódigoError)")
        [void]$FinalReport.AppendLine("Parche:  $($Update.Título)")
        [void]$FinalReport.AppendLine("-" * 50)
    }
} else {
    [void]$FinalReport.AppendLine($UpdateHistory)
}

# 4. Guardar en el archivo de texto
$FinalReport.ToString() | Out-File -FilePath $OutputFile -Encoding utf8

Write-Host "Reporte generado con éxito en tu Escritorio:" -ForegroundColor Green
Write-Host $OutputFile -ForegroundColor Yellow