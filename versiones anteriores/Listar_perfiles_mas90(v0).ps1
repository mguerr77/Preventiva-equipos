<#
.SYNOPSIS
    Script de auditoría de perfiles inactivos.
    Utiliza comprobación de metadatos de archivos (ntuser.ini / ntuser.dat) 
    para evadir los falsos positivos generados por WMI y procesos en segundo plano.
#>

$LimiteDias = 90
$FechaCorte = (Get-Date).AddDays(-$LimiteDias)

Write-Host "Auditando perfiles inactivos desde antes del: $($FechaCorte.ToShortDateString())`n" -ForegroundColor Cyan

# Extracción de perfiles mediante CIM, excluyendo cuentas integradas del sistema (Special = $false)
$Perfiles = Get-CimInstance -ClassName Win32_UserProfile | Where-Object { $_.Special -eq $false }

$Resultado = foreach ($Perfil in $Perfiles) {
    # Resolución de SID a nombre de cuenta NT
    try {
        $Usuario = (New-Object System.Security.Principal.SecurityIdentifier($Perfil.SID)).Translate([System.Security.Principal.NTAccount]).Value
    } catch {
        $Usuario = "Cuenta huérfana o eliminada del AD ($($Perfil.SID))"
    }

    $RutaPerfil = $Perfil.LocalPath
    $FechaWMI = $Perfil.LastUseTime
    $FechaReal = $FechaWMI

    # ESTRATEGIA: Inspección de archivos críticos de perfil interactivo
    $RutaIni = Join-Path -Path $RutaPerfil -ChildPath "ntuser.ini"
    $RutaDat = Join-Path -Path $RutaPerfil -ChildPath "ntuser.dat"

    # Priorizamos ntuser.ini porque no suele ser invocado por servicios de actualización en segundo plano
    if (Test-Path $RutaIni -PathType Leaf) {
        $FechaReal = (Get-Item $RutaIni -Force).LastWriteTime
    } elseif (Test-Path $RutaDat -PathType Leaf) {
        # Fallback a ntuser.dat si el .ini no estuviera disponible
        $FechaReal = (Get-Item $RutaDat -Force).LastWriteTime
    }

    # Prevención de errores si el perfil está corrupto y carece de fechas
    if ($null -eq $FechaReal) { continue }

    $TiempoInactivo = (Get-Date) - $FechaReal
   
    [PSCustomObject]@{
        Usuario           = $Usuario
        RutaPerfil        = $RutaPerfil
        UltimoAccesoWMI   = $FechaWMI  # Conservado para comparar la desviación analítica
        UltimoAccesoReal  = $FechaReal
        DiasInactivo      = [Math]::Floor($TiempoInactivo.TotalDays)
        SID               = $Perfil.SID
    }
}

# Filtrado y proyección de la tabla de resultados
$PerfilesInactivos = $Resultado | Where-Object { $_.DiasInactivo -gt $LimiteDias } | Sort-Object DiasInactivo -Descending

if ($PerfilesInactivos) {
    Write-Host "Se han detectado los siguientes perfiles con inactividad superior a $LimiteDias días:`n" -ForegroundColor Yellow
    $PerfilesInactivos | Format-Table Usuario, RutaPerfil, UltimoAccesoReal, DiasInactivo -AutoSize
} else {
    Write-Host "No se han detectado perfiles con más de $LimiteDias días de inactividad real." -ForegroundColor Green
}
