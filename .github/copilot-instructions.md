# Copilot instructions for this repository

- This repository is not a traditional app; it is a Windows maintenance toolkit built from root `.bat` launchers and PowerShell scripts under `codigo/`.
- The operational flow is explicit: root files such as `Paso1-ejecutar_ReporteActualizaciones.bat` call `powershell -ExecutionPolicy Bypass -File "%~dp0\Codigo\...ps1"` and then `pause`.
- Most scripts are designed to run on a live machine and expect elevated privileges. Preserve the existing admin checks, e.g. `([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(...)`.
- The repo assumes a USB drive labeled `KINGSTON` and writes reports under `X:\preventiva\...` using the host name, such as `Reporte_Sistema_y_Actualizaciones-v0.2-<PC>.txt`.
- Architecture is procedural and imperative: one script = one maintenance task. There are no build/test pipelines, packages, or application services to wire up.
- `codigo/ReporteActualizaciones.ps1` uses `Microsoft.Update.Session` and `QueryHistory()` to inspect Windows Update history and flag KB updates with errors/failures.
- `codigo/InstalarActualizador.ps1` installs `PSWindowsUpdate` from the PowerShell gallery when needed; `codigo/InstalarParchesKB.ps1` then accepts a list of KB IDs and calls `Get-WindowsUpdate -KBArticleID ... -Install -AcceptAll -AutoReboot`.
- `codigo/Listar_perfiles_mas90v0.3.ps1` is the main profile-audit script: it combines `Win32_UserProfile`, Event ID `4624` logon history, and heuristics from `AppData\Roaming\Microsoft\Windows\Recent` / Desktop to estimate inactivity.
- `codigo/eliminar-perfiles-registro-y-directorio.ps1` expects a text file list of folder names and removes the corresponding `Win32_UserProfile` entries and directory tree.
- `codigo/Limpieza_cache_y_temporales.ps1` performs destructive cleanup: it stops `bits` and `wuauserv`, clears temp folders, invokes `cleanmgr.exe /sagerun`, and runs `DISM.exe /Online /Cleanup-Image /StartComponentCleanup /ResetBase`.
- `codigo/DesactivaIPV6.ps1` disables IPv6 on adapters and sets registry `HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters\DisabledComponents = 255`, then warns that a reboot is mandatory.
- Preserve the Spanish user-facing style: `Write-Host`, color-coded status, and a runbook tone rather than framework-like code.
- Prefer explicit validation gates (`Test-Path`, `if (-not ...)`, `ErrorAction Stop`) before destructive actions such as deleting profiles, temp folders, or registry keys.
- When editing scripts, keep the launcher/batch contract intact: same script path under `codigo/`, same root step file name, same output conventions.
- Do not introduce package managers, CI files, or app scaffolding unless the task explicitly requires it; this repo’s value is direct, machine-level maintenance automation.
- Validation is practical: run the relevant `.bat` or `.ps1` in an elevated Windows PowerShell session and inspect the generated report or console output, rather than chasing unit tests.
- Prefer minimal, surgical edits; these scripts are often standalone and heavily procedural, and broad refactors can break operational assumptions.
- If you add a new maintenance script, mirror the existing pattern: root `.bat` launcher, script under `codigo/`, Spanish comments, and explicit admin/USB checks where applicable.
