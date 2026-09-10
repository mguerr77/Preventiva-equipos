# Instalar el proveedor de paquetes necesario si no lo tienes
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force

# Instalar el módulo PSWindowsUpdate desde la galería oficial
Install-Module -Name PSWindowsUpdate -Force
