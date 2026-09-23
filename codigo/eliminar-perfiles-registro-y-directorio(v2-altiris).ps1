########################################################################################################
# DESCRIPTION
# 
#    Eliminación de perfiles de usuario con mas de 180 días sin uso.  
#    Toma como entrada un archivo de texto generado por el paso anterior. Este se aloja en 
#    la carpeta c:\preventiva y contiene la lista de usuarios a eliminar. Es conveniente revisar
#    esta lista para evitar borrar perfiles necesarios y por precaución.
#    El script se encarga de recorrer el registro, elimina las entradas vinculadas en este 
#    y purga los directorios de forma definitiva.   (consigue liberar mucho espacio en disco)
#        
########################################################################################################

# =========================
# RUTA DE ENTRADA: usar carpeta local del sistema (C:\preventiva)
# =========================
# Directorio de trabajo en la raíz de la unidad del sistema
$rootPreventiva = "$env:SystemDrive\preventiva"
if (-not (Test-Path $rootPreventiva)) {
    try {
        New-Item -ItemType Directory -Path $rootPreventiva -Force -ErrorAction Stop | Out-Null
        Write-Host "Carpeta de trabajo creada: $rootPreventiva" -ForegroundColor DarkGray
    } catch {
        Write-Host "ERROR: no se pudo crear la carpeta $rootPreventiva : $_" -ForegroundColor Red
        exit 1
    }
}

[string]$RutaArchivoEntrada = Join-Path $rootPreventiva 'usuarios.txt'

# En ejecución desde gestión central, no pedimos interacción. Si no existe, fallamos.
if (-not (Test-Path $RutaArchivoEntrada -PathType Leaf)) {
    Write-Host "ERROR: no se encontró el archivo de entrada esperado: $RutaArchivoEntrada" -ForegroundColor Red
    exit 1
}

$DirectorioBasePerfiles = "C:\Users"

# Nombres de perfiles que NUNCA deben eliminarse (comparación case-insensitive)
$NombresExcluidos = @(
    'Acceso público',
    'Admin',
    'Administrador',
    'Default',
    'Srvc_SC02Altiris',
    'Public'
)
$NombresExcluidosLower = $NombresExcluidos | ForEach-Object { $_.ToLower() }

Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host " INICIANDO PROTOCOLO DE EXPURGACIÓN LÓGICA ESTÁNDAR" -ForegroundColor Cyan
Write-Host "========================================================================`n" -ForegroundColor Cyan

$CarpetasCandidatas = Get-Content -Path $RutaArchivoEntrada

foreach ($NombreCarpeta in $CarpetasCandidatas) {
    $NombreCarpeta = $NombreCarpeta.Trim()
    if ([string]::IsNullOrWhiteSpace($NombreCarpeta)) { continue }

    # Omitir perfiles protegidos por nombre
    if ($NombresExcluidosLower -contains $NombreCarpeta.ToLower()) {
        Write-Host "   [SKIP] Nombre protegido: $NombreCarpeta" -ForegroundColor Yellow
        continue
    }
   
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