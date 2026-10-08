<#
Este script permite inspeccionar las sesiones de usuario activas en el sistema y determinar si están bloqueadas o 
 activas. Requiere privilegios administrativos elevados para poder inspeccionar la propiedad 'UserName' 
 de los procesos de otros usuarios.
#>

# 1. Obtenemos las sesiones que tienen una shell cargada (usuarios iniciados)
$sesionesIniciadas = Get-Process -Name explorer -IncludeUserName -ErrorAction SilentlyContinue

# 2. Obtenemos las instancias de la interfaz de bloqueo
$procesosBloqueo = Get-Process -Name LogonUI -ErrorAction SilentlyContinue

# 3. Correlacionamos los conjuntos mediante el SessionId
$analisisSesiones = foreach ($sesion in $sesionesIniciadas) {
    $id = $sesion.SessionId
    
    # Determinamos si el proceso LogonUI existe en este mismo SessionId
    $interfazBloqueoActiva = $procesosBloqueo | Where-Object { $_.SessionId -eq $id }
    
    if ($interfazBloqueoActiva) {
        $estadoCondicion = "Bloqueada (En latencia)"
    } else {
        $estadoCondicion = "Activa y en uso (Interacción directa)"
    }

    [PSCustomObject]@{
        Identificador = $id
        Usuario       = $sesion.UserName
        Estado        = $estadoCondicion
        MemoriaFisica = "{0:N2} MB" -f ($sesion.WorkingSet64 / 1MB)
    }
}

# Volcado estructurado por la salida estándar
$analisisSesiones | Sort-Object Identificador | Format-Table -AutoSize
# Código de salida 0 para que Altiris lo considere correcto
exit 0