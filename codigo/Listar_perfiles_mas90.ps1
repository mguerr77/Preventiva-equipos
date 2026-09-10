<#
.SYNOPSIS
    Auditoría pericial de perfiles inactivos.
    Correlaciona metadatos WMI, heurística de ficheros y el registro de eventos 
    de seguridad (EventID 4624) mediante consultas XPath de alto rendimiento.
#>

$LimiteDias = 90
$FechaCorte = (Get-Date).AddDays(-$LimiteDias)

Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host " INICIANDO AUDITORÍA FORENSE DE PERFILES (Umbral: $LimiteDias días)" -ForegroundColor Cyan
Write-Host " Fecha de corte algorítmica: $($FechaCorte.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Cyan
Write-Host "========================================================================`n" -ForegroundColor Cyan

# Extracción de perfiles locales (CIM), excluyendo cuentas del sistema
$Perfiles = Get-CimInstance -ClassName Win32_UserProfile | Where-Object { $_.Special -eq $false }

$Resultado = foreach ($Perfil in $Perfiles) {
    try {
        $Usuario = (New-Object System.Security.Principal.SecurityIdentifier($Perfil.SID)).Translate([System.Security.Principal.NTAccount]).Value
    } catch {
        $Usuario = "Cuenta huérfana ($($Perfil.SID))"
    }

    Write-Host "-> Analizando perfil de dominio: $Usuario" -ForegroundColor Yellow
    
    # -------------------------------------------------------------------------
    # CAPA 1: Extracción WMI (Alta probabilidad de falso positivo)
    # -------------------------------------------------------------------------
    $FechaWMI = $Perfil.LastUseTime
    Write-Host "   [1. WMI] LastUseTime registrado          : $($FechaWMI)" -ForegroundColor DarkGray

    # -------------------------------------------------------------------------
    # CAPA 2: Heurística de Artefactos (Vulnerable a escaneos de EDR/Antivirus)
    # -------------------------------------------------------------------------
    $FechaHeuristica = $null
    $RutaRecent  = Join-Path -Path $Perfil.LocalPath -ChildPath "AppData\Roaming\Microsoft\Windows\Recent"
    $RutaDesktop = Join-Path -Path $Perfil.LocalPath -ChildPath "Desktop"

    if (Test-Path $RutaRecent) {
        $FechaHeuristica = (Get-Item $RutaRecent -Force).LastWriteTime
        Write-Host "   [2. HEURÍSTICA] Modificación 'Recent'    : $($FechaHeuristica)" -ForegroundColor DarkGray
    } elseif (Test-Path $RutaDesktop) {
        $FechaHeuristica = (Get-Item $RutaDesktop -Force).LastWriteTime
        Write-Host "   [2. HEURÍSTICA] Modificación 'Desktop'   : $($FechaHeuristica)" -ForegroundColor DarkGray
    }

    # -------------------------------------------------------------------------
    # CAPA 3: Registro de Eventos de Seguridad (La fuente criptográfica más pura)
    # -------------------------------------------------------------------------
    $FechaEventLog = $null
    
    # Construcción de la consulta XPath optimizada para el motor de eventos
    $FiltroXPath = @"
    <QueryList>
      <Query Id="0" Path="Security">
        <Select Path="Security">
          *[System[EventID=4624]]
          and
          *[EventData[Data[@Name='TargetUserSid']='$($Perfil.SID)'] 
          and 
          (Data[@Name='LogonType']='2' or Data[@Name='LogonType']='7' or Data[@Name='LogonType']='10' or Data[@Name='LogonType']='11')]
        </Select>
      </Query>
    </QueryList>
"@

    try {
        # Extraemos únicamente el último evento registrado para minimizar el consumo de CPU y RAM
        $EventoLogon = Get-WinEvent -FilterXml $FiltroXPath -MaxEvents 1 -ErrorAction Stop
        $FechaEventLog = $EventoLogon.TimeCreated
        Write-Host "   [3. EVENT LOG] Último Logon ID 4624      : $($FechaEventLog)" -ForegroundColor Green
    } catch {
        Write-Host "   [3. EVENT LOG] Sin registros de Logon    : El evento ha sido purgado o no existe." -ForegroundColor Red
    }

    # -------------------------------------------------------------------------
    # DETERMINACIÓN DEL VÉRTICE TEMPORAL MÁS PRECISO
    # -------------------------------------------------------------------------
    $FechaReal = $null
    $MetodoUtilizado = ""

    # Jerarquía de confianza: EventLog > Heurística > WMI
    if ($null -ne $FechaEventLog) {
        $FechaReal = $FechaEventLog
        $MetodoUtilizado = "Visor de Eventos (Alta Fiabilidad)"
    } elseif ($null -ne $FechaHeuristica) {
        $FechaReal = $FechaHeuristica
        $MetodoUtilizado = "Heurística de Ficheros (Fiabilidad Media)"
    } else {
        $FechaReal = $FechaWMI
        $MetodoUtilizado = "Atributo WMI (Baja Fiabilidad)"
    }

    # Control de excepciones por perfiles corruptos
    if ($null -eq $FechaReal) { continue }

    $TiempoInactivo = (Get-Date) - $FechaReal
    $DiasInactivosCalc = [Math]::Floor($TiempoInactivo.TotalDays)
   
    Write-Host "   [CONCLUSIÓN] Días de inactividad técnica : $DiasInactivosCalc (Fuente: $MetodoUtilizado)`n" -ForegroundColor White

    [PSCustomObject]@{
        Usuario           = $Usuario
        RutaPerfil        = $Perfil.LocalPath
        UltimoAccesoReal  = $FechaReal
        DiasInactivo      = $DiasInactivosCalc
        FuenteDatos       = $MetodoUtilizado
    }
}

# Consolidación final
$PerfilesInactivos = $Resultado | Where-Object { $_.DiasInactivo -gt $LimiteDias } | Sort-Object DiasInactivo -Descending

Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host " RESUMEN ESTRUCTURAL" -ForegroundColor Cyan
Write-Host "========================================================================`n" -ForegroundColor Cyan

if ($PerfilesInactivos) {
    Write-Host "Perfiles que superan el umbral estricto de inactividad ($LimiteDias días):`n" -ForegroundColor Yellow
    $PerfilesInactivos | Format-Table Usuario, RutaPerfil, UltimoAccesoReal, DiasInactivo, FuenteDatos -AutoSize
} else {
    Write-Host "Evaluación pericial concluida: No existen perfiles con inactividad superior a $LimiteDias días bajo los criterios analizados." -ForegroundColor Green
}
