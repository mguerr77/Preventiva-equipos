###########################################################################################
# .Descripción
#    Auditoría de perfiles inactivos.
#    Correlaciona metadatos WMI, heurística de ficheros y el registro de eventos 
#    de seguridad (EventID 4624) mediante consultas XPath
#>###########################################################################################

# =========================
# RUTA DE TRABAJO: usar carpeta local del sistema (C:\preventiva)
# =========================
Write-Host "[TRAZA] Inicializando rutas de trabajo..." -ForegroundColor DarkGray
$rootPreventiva = "$env:SystemDrive\preventiva"
Write-Host "[TRAZA] Ruta base: $rootPreventiva" -ForegroundColor DarkGray

if (-not (Test-Path $rootPreventiva)) {
    Write-Host "[TRAZA] Carpeta no existe, creando: $rootPreventiva" -ForegroundColor DarkGray
    try {
        New-Item -ItemType Directory -Path $rootPreventiva -Force -ErrorAction Stop | Out-Null
        Write-Host "[✓] Carpeta creada exitosamente" -ForegroundColor Green
    } catch {
        Write-Host "[✗] ERROR: No se pudo crear la carpeta: $_" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "[✓] Carpeta ya existe" -ForegroundColor Green
}

# Nombre archivo = nombre PC
$nombrePC = $env:COMPUTERNAME
Write-Host "[TRAZA] Nombre del equipo: $nombrePC" -ForegroundColor DarkGray
$OutputFile = "$rootPreventiva\Reporte_usuarios-plus-180-v0.3-$nombrePC.txt"
Write-Host "[TRAZA] Ruta del archivo de salida: $OutputFile" -ForegroundColor DarkGray

# Protecciones de perfiles que no deben eliminarse
$NombresExcluidos = @(
    'Acceso público',
    'Admin',
    'Administrador',
    'Default',
    'Srvc_SC02Altiris',
    'Public',
    'Administrator',
    'DefaultAppPool',
    'defaultuser0',
    'WDAGUtilityAccount',
    'Default User',
    'All Users'
)
$NombresExcluidosLower = $NombresExcluidos | ForEach-Object { $_.ToLowerInvariant() }

# Borra el archivo previo si existe
if (Test-Path $OutputFile) {
    Write-Host "[TRAZA] Archivo anterior existe, eliminando: $OutputFile" -ForegroundColor DarkGray
    try {
        Remove-Item $OutputFile -Force -ErrorAction Stop
        Write-Host "[✓] Archivo anterior eliminado" -ForegroundColor Green
    } catch {
        Write-Host "[✗] ERROR al eliminar archivo anterior: $_" -ForegroundColor Red
    }
} else {
    Write-Host "[TRAZA] No existe archivo anterior (es la primera ejecución)" -ForegroundColor DarkGray
}

# Configuración del archivo de salida

# parámetros de filtro de fecha

$LimiteDias = 180
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

    # Excluir perfiles protegidos
    if ($NombresExcluidosLower -contains $Usuario.ToLowerInvariant()) {
        Write-Host "   [SKIP] Perfil protegido: $Usuario" -ForegroundColor Yellow
    #    return
    }

    $NombreCarpeta = Split-Path -Path $Perfil.LocalPath -Leaf
    if ($NombresExcluidosLower -contains $NombreCarpeta.ToLowerInvariant()) {
        Write-Host "   [SKIP] Carpeta protegida: $NombreCarpeta" -ForegroundColor Yellow
    #    return
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
    # CAPA 3: Registro de Eventos de Seguridad 
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

    # Jerarquía de confianza: EventLog > Heuristica > WMI
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
    
    # Escritura de cabecera informativa en el archivo de salida
    Write-Host "[TRAZA] Preparando cabecera del reporte..." -ForegroundColor DarkGray
    $cabecera = @"
========================================================================
REPORTE DE AUDITORÍA DE PERFILES INACTIVOS
========================================================================
Fecha de generación: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Equipo: $nombrePC
Umbral de inactividad: $LimiteDias días
Fecha de corte: $($FechaCorte.ToString('yyyy-MM-dd HH:mm:ss'))
Cantidad de perfiles detectados: $($PerfilesInactivos.Count)
========================================================================
LISTADO DE CARPETAS CANDIDATAS PARA ELIMINACIÓN:
========================================================================
"@
    
    Write-Host "[TRAZA] Escribiendo cabecera en archivo: $OutputFile" -ForegroundColor DarkGray
    try {
        Add-Content -Path $OutputFile -Value $cabecera -ErrorAction Stop
        Write-Host "[✓] Cabecera escribida exitosamente (líneas: $($cabecera.Split([Environment]::NewLine).Count))" -ForegroundColor Green
    } catch {
        Write-Host "[✗] ERROR al escribir cabecera: $_" -ForegroundColor Red
        Write-Host "[✗] Stack: $($_.Exception.StackTrace)" -ForegroundColor Red
    }
    
    # Análisis sintáctico y generación del archivo de parámetros
    # Se escribe SOLO el nombre de la carpeta en cada línea (compatible con eliminar-perfiles-registro-y-directorio.ps1)
    Write-Host "[TRAZA] Iniciando iteración de perfiles ($($PerfilesInactivos.Count) total)..." -ForegroundColor DarkGray
    $contadorEscrito = 0
    $contadorSaltado = 0
    
    foreach ($Perfil in $PerfilesInactivos) {
        $NombreCarpeta = Split-Path -Path $Perfil.RutaPerfil -Leaf
        Write-Host "[TRAZA] Procesando: $NombreCarpeta (Inactivo: $($Perfil.DiasInactivo) días)" -ForegroundColor DarkGray
        
        if ($NombresExcluidosLower -contains $NombreCarpeta.ToLowerInvariant()) {
            Write-Host "   [SKIP] Excluido de la exportación: $NombreCarpeta" -ForegroundColor Yellow
            $contadorSaltado++
            continue
        }
        
        try {
            # Escribir información detallada como comentario, luego el nombre de carpeta limpio
            #$linea = "# $NombreCarpeta | Inactivo $($Perfil.DiasInactivo) días | Último acceso: $($Perfil.UltimoAccesoReal.ToString('yyyy-MM-dd')) | Fuente: $($Perfil.FuenteDatos)"
            #Add-Content -Path $OutputFile -Value $linea -ErrorAction Stop
            #Write-Host "   [✓] Línea comentada escrita" -ForegroundColor DarkGray
            
            Add-Content -Path $OutputFile -Value $NombreCarpeta -ErrorAction Stop
            Write-Host "   [✓] Nombre de carpeta escrito" -ForegroundColor DarkGray
            $contadorEscrito++
        } catch {
            Write-Host "   [✗] ERROR al escribir $NombreCarpeta : $_" -ForegroundColor Red
        }
    }
    
    Write-Host "[TRAZA] Cierre del archivo..." -ForegroundColor DarkGray
    try {
        "" | Add-Content -Path $OutputFile -ErrorAction Stop
        Write-Host "   [✓] Línea vacía escrita" -ForegroundColor DarkGray
        
        "========================================================================" | Add-Content -Path $OutputFile -ErrorAction Stop
        Write-Host "   [✓] Línea de cierre escrita" -ForegroundColor DarkGray
    } catch {
        Write-Host "   [✗] ERROR al escribir cierre: $_" -ForegroundColor Red
    }
    
    Write-Host "`n[✓] RESUMEN DE EXPORTACIÓN:" -ForegroundColor Green
    Write-Host "    - Perfiles procesados: $contadorEscrito" -ForegroundColor Green
    Write-Host "    - Perfiles excluidos: $contadorSaltado" -ForegroundColor Green
    Write-Host "    - Ruta del archivo: $OutputFile" -ForegroundColor Green
    
    # Verificar que el archivo existe después de la creación
    if (Test-Path $OutputFile) {
        $fileSize = (Get-Item $OutputFile).Length
        $fileLines = @(Get-Content $OutputFile).Count
        Write-Host "    - Tamaño del archivo: $fileSize bytes" -ForegroundColor Green
        Write-Host "    - Líneas en el archivo: $fileLines" -ForegroundColor Green
    } else {
        Write-Host "    [✗] ADVERTENCIA: El archivo de salida NO EXISTE después de la creación" -ForegroundColor Red
        # Código de salida 1 para que Altiris lo considere incorrecto
        exit 1
    }
} else {
    Write-Host "Evaluación pericial concluida: No existen perfiles con inactividad superior a $LimiteDias días bajo los criterios analizados." -ForegroundColor Green
    # Código de salida 0 para que Altiris lo considere correcto
    exit 0
}
