# Verificar si el módulo PSWindowsUpdate está instalado antes de continuar
if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    Write-Host "El módulo PSWindowsUpdate no está instalado." -ForegroundColor Yellow
    Write-Host "Instalándolo automáticamente por ti..." -ForegroundColor Cyan
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false
    Install-Module -Name PSWindowsUpdate -Force -Confirm:$false
}

# Inicializar la lista vacía para guardar los KBs
$ListaKBs = @()

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "      INSTALADOR FORZADO DE PARCHES KB           " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Introduce los códigos de tu reporte (ej: KB5034765)"
Write-Host "Cuando termines, deja el campo vacío y pulsa ENTER."
Write-Host "--------------------------------------------------"

# Bucle interactivo para pedir los datos
do {
    $Entrada = (Read-Host "Introduce un código KB").Trim().ToUpper()
    
    if ($Entrada -ne "") {
        # Pequeña validación: asegurarse de que el usuario escribe el prefijo "KB"
        if (-not $Entrada.StartsWith("KB")) {
            $Entrada = "KB" + $Entrada
        }
        
        # Añadir a nuestra lista si no está duplicado
        if ($Entrada -notin $ListaKBs) {
            $ListaKBs += $Entrada
            Write-Host "-> Añadido: $Entrada" -ForegroundColor Green
        } else {
            Write-Host "-> Ese código ya lo habías introducido." -ForegroundColor Yellow
        }
    }
} while ($Entrada -ne "")

# Procesar la lista si contiene elementos
if ($ListaKBs.Count -gt 0) {
    Write-Host "`n==================================================" -ForegroundColor Cyan
    Write-Host "Se van a forzar los siguientes parches:" -ForegroundColor Yellow
    Write-Host ($ListaKBs -join ", ") -ForegroundColor White
    Write-Host "==================================================" -ForegroundColor Cyan
    
    # Lanzar el comando unificado pasando la lista completa
    Get-WindowsUpdate -KBArticleID $ListaKBs -Install -AcceptAll -AutoReboot
} else {
    Write-Host "`nNo has introducido ningún código KB. Proceso cancelado." -ForegroundColor Red
}