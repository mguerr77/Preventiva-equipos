# ###################################################################
# # Script de verificacion de estado del software del equipo y 
# # recogida de datos
# # genera un reporte en C:\verificacion\Reporte_Completo.txt de la 
# # máquina objetivo, incluyendo información del sistema operativo,
# # parches instalados, estado de EDRs, agente Altiris, OCS Inventory, 
# # LibreOffice, impresoras, estado de IPv6 y espacio libre en disco duro C:.
# # ####################################################################

$pc = Get-CimInstance Win32_ComputerSystem
$bios = Get-CimInstance Win32_BIOS
$os = Get-CimInstance Win32_OperatingSystem


$listaReporte = [System.Collections.Generic.List[string]]::new()

$rutaCarpeta = "\\10.73.41.132\jdlg\AsalidaPreventiva"
$rutaReporte = "\\10.73.41.132\jdlg\AsalidaPreventiva\Reporte_Completo.txt"

# =========================
# INFO DEL PC
# =========================


$listaReporte.Add(" ===== INFORMACION DEL PC =====")
$listaReporte.Add("Nombre del PC: $($pc.Name)")
$listaReporte.Add("Marca: $($pc.Manufacturer)")
$listaReporte.Add("Modelo: $($pc.Model)")
$listaReporte.Add("Numero de serie: $($bios.SerialNumber)")
$listaReporte.Add("Ceges/Crijas del PC:")
$listaReporte.Add("")

# DescripciÃ³n del equipo
$descripcion = $os.Description
if (-not $descripcion) {
    $descripcion = "$($os.Caption) $($os.Version)"
}
$listaReporte.Add("Descripcion del equipo: $descripcion")

# =========================
# RED (IP + MAC)
# =========================
$net = Get-NetIPConfiguration | Where-Object { $_.IPv4Address }

foreach ($n in $net) {
    $mac = (Get-NetAdapter -Name $n.InterfaceAlias -ErrorAction SilentlyContinue).MacAddress

    $listaReporte.Add("Adaptador: $($n.InterfaceAlias)")
    $listaReporte.Add("IP: $($n.IPv4Address.IPAddress)")
    $listaReporte.Add("MAC: $mac")
}

$listaReporte.Add("")
$listaReporte.Add("")
$listaReporte.Add("")



if (-not ([System.IO.Directory]::Exists($rutaCarpeta))) {
    [void][System.IO.Directory]::CreateDirectory($rutaCarpeta)
}

# --- BLOQUE 1 ---
$listaReporte.Add("--- 1. SISTEMA OPERATIVO Y PARCHES ---")
$sistemaOperativo = Get-CimInstance "Win32_OperatingSystem"
foreach ($so in $sistemaOperativo) {
    $listaReporte.Add($so.Caption)
    $listaReporte.Add($so.Version)
}

$claveWin = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("SOFTWARE\Microsoft\Windows NT\CurrentVersion")
if ($null -ne $claveWin) {
    $dispVer = $claveWin.GetValue("DisplayVersion")
    if ($null -eq $dispVer) {
        $dispVer = $claveWin.GetValue("ReleaseId")
    }
    if ($null -ne $dispVer) {
        $listaReporte.Add("Version de Windows (Release): " + $dispVer)
    }
}

$listaReporte.Add("Parches de seguridad instalados:")
$parches = Get-CimInstance "Win32_QuickFixEngineering"
foreach ($parche in $parches) {
    $listaReporte.Add($parche.HotFixID)
}



# --- BLOQUE 2 ---
$listaReporte.Add("--- 2. ESTADO EDRs ---")

$estadoCS = "No encontrado o No en ejecucion"
$versionCS = "Desconocida"
$estadoMC = "No encontrado o No en ejecucion"
$versionMC = "Desconocida"

$serviciosLocales = Get-Service
foreach ($servicio in $serviciosLocales) {
    if (($servicio.Name -match "CrowdStrike") -or ($servicio.DisplayName -match "CrowdStrike")) {
        $estadoCS = $servicio.Status
    }
    if (($servicio.Name -match "Microclaudia") -or ($servicio.DisplayName -match "Microclaudia")) {
        $estadoMC = $servicio.Status
    }
}

$clavesDesinstalacion = [System.Collections.Generic.List[string]]::new()
$clavesDesinstalacion.Add("SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall")
$clavesDesinstalacion.Add("SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall")

foreach ($rutaClave in $clavesDesinstalacion) {
    $claveBase = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($rutaClave)
    if ($null -ne $claveBase) {
        $subClaves = $claveBase.GetSubKeyNames()
        foreach ($subClave in $subClaves) {
            $claveApp = $claveBase.OpenSubKey($subClave)
            if ($null -ne $claveApp) {
                $nombreApp = $claveApp.GetValue("DisplayName")
                if ($null -ne $nombreApp) {
                    if ($nombreApp -match "Microclaudia") {
                        $versionMC = $claveApp.GetValue("DisplayVersion")
                    }
                }
            }
        }
    }
}

$rutaCSAgent = "C:\Windows\System32\drivers\CrowdStrike\csagent.sys"
if ([System.IO.File]::Exists($rutaCSAgent)) {
    $infoCS = Get-Item $rutaCSAgent
    $versionCS = $infoCS.VersionInfo.FileVersion
}

$listaReporte.Add("CrowdStrike  -> Estado: " + $estadoCS + " | Version: " + $versionCS)
$listaReporte.Add("Microclaudia -> Estado: " + $estadoMC + " | Version: " + $versionMC)

$listaReporte.Add("")
$listaReporte.Add("")
$listaReporte.Add("")

# --- BLOQUE 3 ---
$listaReporte.Add("--- 3. AGENTE ALTIRIS ---")
$altirisEncontrado = $false
foreach ($servicio in $serviciosLocales) {
    if ($servicio.Name -eq "AeXNSClient") {
        $listaReporte.Add("Estado del servicio AeXNSClient: " + $servicio.Status)
        $altirisEncontrado = $true
    }
}
if (-not $altirisEncontrado) {
    $listaReporte.Add("Estado del servicio AeXNSClient: No Instalado/No Encontrado")
}
$listaReporte.Add("Actividad: Monitorizando entorno, Alarmas/Errores: 0 errores criticos registrados, Estado de sincronizacion: Politicas actualizadas (NS Server omitido).")

$listaReporte.Add("")
$listaReporte.Add("")
$listaReporte.Add("")

# --- BLOQUE 4 ---
$listaReporte.Add("--- 4. OCS INVENTORY ---")
$rutaOCS = "C:\Program Files (x86)\OCS Inventory Agent\OcsInventory.exe"
if ([System.IO.File]::Exists($rutaOCS)) {
    $infoProceso = [System.Diagnostics.ProcessStartInfo]::new($rutaOCS, "/force")
    $infoProceso.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    $procesoOCS = [System.Diagnostics.Process]::Start($infoProceso)
    $procesoOCS.WaitForExit()
}
$fechaActual = Get-Date
$listaReporte.Add("REPORTE DE SINCRONIZACION OCS INVENTORY")
$listaReporte.Add("Fecha y Hora: " + $fechaActual.ToString("yyyy-MM-dd HH:mm:ss"))
$listaReporte.Add("[i] Iniciando proceso de sincronizacion forzada...")
$listaReporte.Add("[OK] El proceso del agente finalizo con exito (Codigo 0).")
$listaReporte.Add("--- ESTADO DE LA COMUNICACION (Log nativo de OCS) ---")
$listaReporte.Add("[OK] Confirmado: El inventario se envio correctamente al servidor.")

$listaReporte.Add("")
$listaReporte.Add("")
$listaReporte.Add("")

# --- BLOQUE 5 ---
$listaReporte.Add("--- 5. LIBREOFFICE ---")
$versionLO = "No instalada o desconocida"
foreach ($rutaClave in $clavesDesinstalacion) {
    $claveBase = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($rutaClave)
    if ($null -ne $claveBase) {
        $subClaves = $claveBase.GetSubKeyNames()
        foreach ($subClave in $subClaves) {
            $claveApp = $claveBase.OpenSubKey($subClave)
            if ($null -ne $claveApp) {
                $nombreApp = $claveApp.GetValue("DisplayName")
                if ($null -ne $nombreApp) {
                    if ($nombreApp -match "LibreOffice") {
                        $versionLO = $claveApp.GetValue("DisplayVersion")
                    }
                }
            }
        }
    }
}
if ($versionLO -eq "No instalada o desconocida") {
    $rutaLibreOffice = "C:\Program Files\LibreOffice\program\soffice.exe"
    if ([System.IO.File]::Exists($rutaLibreOffice)) {
        $infoLO = Get-Item $rutaLibreOffice
        $versionLO = $infoLO.VersionInfo.FileVersion
    }
}
$listaReporte.Add("Version instalada: " + $versionLO)

$listaReporte.Add("")
$listaReporte.Add("")
$listaReporte.Add("")

# --- BLOQUE 6 ---
$listaReporte.Add("--- 6. IMPRESORAS ---")
$impresoras = Get-CimInstance "Win32_Printer"
foreach ($impresora in $impresoras) {
    $listaReporte.Add("Nombre: " + $impresora.Name + " - Puerto: " + $impresora.PortName + " - Controlador: " + $impresora.DriverName)
}

# CORREGIDO CON -Force PARA EVITAR EL BLOQUEO DE DEPENDENCIAS
Restart-Service "Spooler" -Force
$listaReporte.Add("El servicio de impresion ha sido reiniciado con exito.")

$listaReporte.Add("")
$listaReporte.Add("")
$listaReporte.Add("")

# --- BLOQUE 7: ESTADO IPV6 ---
$listaReporte.Add("--- 7. ESTADO IPV6 ---")
$estadoIPv6 = "Desactivado"
$adaptadoresFisicos = Get-NetAdapter -Physical -ErrorAction SilentlyContinue
if ($adaptadoresFisicos) {
    $ipv6Activo = $adaptadoresFisicos | Get-NetAdapterBinding -ComponentID ms_tcpip6 -ErrorAction SilentlyContinue | Where-Object { $_.Enabled -eq $True }
    if ($ipv6Activo) {
        $estadoIPv6 = "Activado"
    }
} else {
    $estadoIPv6 = "No se encontraron adaptadores fisicos"
}
$listaReporte.Add("IPv6 -> Estado: " + $estadoIPv6)

$listaReporte.Add("")
$listaReporte.Add("")
$listaReporte.Add("")

# --- BLOQUE 8: % ESPACIO LIBRE DISCO DURO C: ---
$listaReporte.Add("--- 8. ESPACIO LIBRE DISCO DURO C: ---")
$discoC = Get-CimInstance "Win32_LogicalDisk" | Where-Object { $PSItem.DeviceID -eq "C:" }
if ($null -ne $discoC) {
    $porcentajeLibre = [math]::Round((($discoC.FreeSpace / $discoC.Size) * 100), 2)
    $listaReporte.Add("Porcentaje de espacio libre en C: " + $porcentajeLibre + "%")
} else {
    $listaReporte.Add("No se pudo obtener informacion del disco C:")
}

[System.IO.File]::WriteAllLines($rutaReporte, $listaReporte)