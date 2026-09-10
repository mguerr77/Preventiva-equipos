<#
.SYNOPSIS
    Motor de expurgación lógica de perfiles de usuario (Modo Estándar).
.DESCRIPTION
    Toma como vector de entrada un archivo de texto, desvincula las colmenas
    del registro mediante WMI (Remove-CimInstance) y purga el directorio
    mediante comandos nativos del sistema operativo de forma rápida y definitiva.
#>

# =========================
# DETECTAR USB
# =========================
$usb = Get-Volume | Where-Object { $_.FileSystemLabel -eq 'KINGSTON' }

if (!$usb) {
    Write-Host 'ERROR: No se ha encontrado el pendrive.'
    exit
}

[string]$RutaArchivoEntrada = "$($usb.DriveLetter):\preventiva\usuarios.txt"


if ([string]::IsNullOrWhiteSpace($RutaArchivoEntrada)) {
    $RutaArchivoEntrada = Read-Host "Introduce la ruta completa del archivo de usuarios (ej: D:\usuarios.txt)"
}

# Normalizar rutas relativas para que no se resuelvan en una carpeta incorrecta
if (-not [System.IO.Path]::IsPathRooted($RutaArchivoEntrada)) {
    $RutaArchivoEntrada = [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $RutaArchivoEntrada))
}

# Si no existe la ruta exacta, intentamos buscar en las ubicaciones habituales del proyecto/USB
if (-not (Test-Path $RutaArchivoEntrada -PathType Leaf)) {
    $Candidatos = @(
        $RutaArchivoEntrada,
        (Join-Path (Get-Location).Path $RutaArchivoEntrada),
        (Join-Path (Get-Location).Path "preventiva\$([System.IO.Path]::GetFileName($RutaArchivoEntrada))"),
        (Join-Path "D:\Preventiva equipos" $RutaArchivoEntrada),
        (Join-Path "D:\Preventiva equipos\preventiva" $([System.IO.Path]::GetFileName($RutaArchivoEntrada))),
        (Join-Path "X:\preventiva" $([System.IO.Path]::GetFileName($RutaArchivoEntrada)))
    ) | Where-Object { $_ -and (Test-Path $_ -PathType Leaf) }

    if ($Candidatos.Count -gt 0) {
        $RutaArchivoEntrada = $Candidatos[0]
    }
}

if (-not (Test-Path $RutaArchivoEntrada -PathType Leaf)) {
    Write-Host "No se encontró el archivo: $RutaArchivoEntrada" -ForegroundColor Red
    $RutaArchivoEntrada = Read-Host "Vuelve a introducir la ruta completa del archivo de usuarios (ej: D:\usuarios.txt)"
}

if (-not (Test-Path $RutaArchivoEntrada -PathType Leaf)) {
    throw "El archivo de usuarios no es válido o no existe: $RutaArchivoEntrada"
}

$DirectorioBasePerfiles = "C:\Users"

Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host " INICIANDO PROTOCOLO DE EXPURGACIÓN LÓGICA ESTÁNDAR" -ForegroundColor Cyan
Write-Host "========================================================================`n" -ForegroundColor Cyan

$CarpetasCandidatas = Get-Content -Path $RutaArchivoEntrada

foreach ($NombreCarpeta in $CarpetasCandidatas) {
    $NombreCarpeta = $NombreCarpeta.Trim()
    if ([string]::IsNullOrWhiteSpace($NombreCarpeta)) { continue }
   
    $RutaAbsoluta = Join-Path -Path $DirectorioBasePerfiles -ChildPath $NombreCarpeta
    Write-Host "-> Procesando vector de destino: $RutaAbsoluta" -ForegroundColor Cyan

    if (Test-Path $RutaAbsoluta) {
       
        # -----------------------------------------------------------------
        # FASE 1: DESENLACE LÓGICO DEL REGISTRO (WMI)
        # -----------------------------------------------------------------
        $PerfilWMI = Get-CimInstance -ClassName Win32_UserProfile | Where-Object { $_.LocalPath -eq $RutaAbsoluta }
       
        if ($PerfilWMI) {
            try {
                # La invocación de Remove-CimInstance elimina el registro y el directorio nativamente
                $PerfilWMI | Remove-CimInstance -ErrorAction Stop
                Write-Host "   [✓] Perfil desvinculado del sistema operativo (SID liberado)." -ForegroundColor Green
            } catch {
                Write-Host "   [!] Anomalía en la desvinculación WMI. Procediendo con el forzado lógico..." -ForegroundColor Red
            }
        } else {
            Write-Host "   [i] Perfil huérfano. No se detectan enlaces en el registro activo." -ForegroundColor DarkYellow
        }

        # -----------------------------------------------------------------
        # FASE 2: PURGA NATIVA DE DIRECTORIO (Contramedida de Persistencia)
        # -----------------------------------------------------------------
        if (Test-Path $RutaAbsoluta) {
            try {
                Remove-Item -Path $RutaAbsoluta -Recurse -Force -ErrorAction Stop
                Write-Host "   [✓] Estructura de directorios purgada definitivamente del sistema de archivos." -ForegroundColor Green
            } catch {
                Write-Host "   [!] Excepción técnica durante la eliminación de artefactos residuales: $_" -ForegroundColor Red
            }
        } else {
            Write-Host "   [✓] La estructura de directorios fue eliminada íntegramente por el subsistema WMI." -ForegroundColor Green
        }
       
    } else {
        Write-Host "   [i] El directorio no existe o ya ha sido neutralizado previamente." -ForegroundColor DarkGray
    }
    Write-Host "------------------------------------------------------------------------" -ForegroundColor DarkGray
}

# ========================================================================
# RUTINA DE LIMPIEZA
# ========================================================================
# Remove-Item -Path $RutaArchivoEntrada -Force -ErrorAction SilentlyContinue
Write-Host "[✓] Operación de mantenimiento concluida. Artefacto de entrada neutralizado." -ForegroundColor Green