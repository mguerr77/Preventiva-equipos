# Ejecutar con privilegios administrativos elevados
$ProfileList = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"
$Profiles = Get-ChildItem $ProfileList | Where-Object { $_.PSChildName -like "S-1-5-21-*" }

Write-Host "Iniciando análisis de orfandad en ProfileList..." -ForegroundColor Cyan

foreach ($P in $Profiles) {
    try {
        $Path = (Get-ItemProperty -Path $P.PSPath -Name ProfileImagePath -ErrorAction Stop).ProfileImagePath
        
        # Condicional ACTIVADO: Solo procede si la carpeta del usuario ya no existe
        if (-not (Test-Path -Path $Path)) {
            Write-Host "Detectado registro huérfano sin directorio físico: $Path" -ForegroundColor Yellow
            Remove-Item -Path $P.PSPath -Recurse -Force -ErrorAction Stop
            Write-Host "[OK] Clave de registro eliminada para el SID: $($P.PSChildName)" -ForegroundColor Green
        }
    }
    catch {
        Write-Warning "Inconsistencia al procesar la clave $($P.PSChildName). Detalles: $_"
    }
}
Write-Host "Proceso de saneamiento finalizado." -ForegroundColor Cyan