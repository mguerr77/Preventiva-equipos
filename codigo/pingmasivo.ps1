# Script para comprobar qué equipos de una lista responden a mensajes ICMP.
# Requiere PowerShell y el ejecutable ping.exe de Windows.

# Parámetros de entrada:
# - ArchivoEquipos: archivo de texto con una dirección IP o nombre de equipo por línea.
# - Salida: archivo donde se escriben los equipos que respondieron (opcional).
# -Verbose: muestra detalles adicionales de cada comprobación en la CLI.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    # Comprueba que el archivo indicado exista y sea un archivo regular.
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string]$ArchivoEquipos,

    # Si no se indica una ruta, se guarda la respuesta en el archivo actual.
    [string]$Salida = "equipos_respondientes.txt"
)

# Lee la lista, elimina líneas vacías, recorta espacios y elimina duplicados.
# Soporta direcciones IP y nombres de equipo que puedan resolverse por DNS.
$equipos = Get-Content -LiteralPath $ArchivoEquipos -Encoding UTF8 |
    Where-Object { $_ -match '\S' } |
    ForEach-Object { $_.Trim() } |
    Sort-Object -Unique

# Se conserva una copia del total para mostrar el progreso en cada iteración.
$equipoTotal = @($equipos).Count
Write-Host "[INFO] Inicio: comprobar $equipoTotal equipo(s) en $ArchivoEquipos" -ForegroundColor Cyan
Write-Progress -Activity "Comprobando equipos" -Status "Iniciando" -PercentComplete 0

# Recorre cada equipo y realiza un único ping con una espera máxima de 1 segundo.
# Se suprime el error de ping para evitar que aparezca texto en la consola.
$respondientes = @()
for ($indice = 0; $indice -lt $equipoTotal; $indice++) {
    $equipo = $equipos[$indice]
    $porcentaje = [Math]::Round((($indice + 1) / $equipoTotal) * 100)
    $numeroEquipo = $indice + 1
    $estadoProgreso = "Procesando equipo $numeroEquipo de ${equipoTotal}: ${equipo}"

    Write-Progress `
        -Activity "Comprobando equipos" `
        -Status $estadoProgreso `
        -PercentComplete $porcentaje

    Write-Verbose "Comprobando '$equipo'..."
    & ping.exe -n 1 -w 1000 $equipo 2>$null | Out-Null

    # ping.exe devuelve código 0 cuando el equipo responde.
    if ($LASTEXITCODE -eq 0) {
        $respondientes += $equipo
        Write-Verbose "El equipo '$equipo' respondió."
    }
    else {
        Write-Verbose "El equipo '$equipo' no respondió o no pudo resolverse."
    }
}

Write-Progress -Activity "Comprobando equipos" -Status "Finalizado" -Completed

# Si existe al menos un equipo respondiente, se guarda la lista en el archivo de salida.
if ($respondientes.Count -gt 0) {
    $respondientes | Set-Content -LiteralPath $Salida -Encoding UTF8
    Write-Host "[OK] Se guardaron $($respondientes.Count) equipo(s) que respondieron en '$Salida'" -ForegroundColor Green
}
else {
    # Crea o sobrescribe el archivo con contenido vacío cuando no hay respuestas.
    Set-Content -LiteralPath $Salida -Value "" -Encoding UTF8
    Write-Host "[ADVERTENCIA] Ningún equipo respondió. Se creó '$Salida' vacío." -ForegroundColor Yellow
}

# Ejemplo de uso:
# .\codigo\pingmasivo.ps1 .\equipos.txt
# .\codigo\pingmasivo.ps1 .\equipos.txt -Salida .\resultados\equipos_respondientes.txt
# .\codigo\pingmasivo.ps1 .\equipos.txt -Verbose
