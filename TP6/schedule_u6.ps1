<#
.SYNOPSIS
    Registra (o quita) las tareas programadas de Windows para el plan de mantenimiento U6.
.DESCRIPTION
    Crea las tareas del Programador de tareas definidas en SPEC_U6.md:
      - FoodStore-U6-Backup        : diaria 02:00  -> backup_foodstore.ps1
      - FoodStore-U6-HealthCheck   : diaria 07:00  -> sql/health_check.sql (psql)
      - FoodStore-U6-Maintenance   : domingo 03:00 -> sql/maintenance.sql  (psql)

    La tarea del simulacro de restauracion (Lunes 08:00, restore_test.ps1) se incluye
    solo con -IncludeRestoreDrill, porque es una operacion de laboratorio que crea y
    elimina una base descartable.

    SEGURIDAD / PRERREQUISITOS:
      - No se almacenan contrasenas. Las tareas corren con la cuenta indicada (-RunAsUser)
        y deben contar con %APPDATA%\postgresql\pgpass.conf (o autenticacion equivalente)
        accesible para esa cuenta, tal como exige SPEC_U6.md.
      - Requiere ejecutar PowerShell como Administrador para registrar tareas con -RunLevel Highest.
      - psql/pg_dump deben estar en el PATH de la cuenta que ejecute las tareas.

.NOTES
    Materia: Bases de Datos II - Unidad 6 (Mantenimiento, respaldo y recuperacion)
    Idempotente: registrar reemplaza la tarea si ya existe. -Remove elimina las tareas.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$HostName = "localhost",
    [int]$Port = 5432,
    [string]$User = "postgres",
    [string]$Database = "foodStore",
    [string]$TaskPath = "\FoodStore\",
    [string]$RunAsUser = "$env:USERDOMAIN\$env:USERNAME",
    [switch]$IncludeRestoreDrill,
    [switch]$Remove
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $ScriptDir) { $ScriptDir = Get-Location }
$SqlDir = Join-Path $ScriptDir "sql"

function Resolve-PowerShellExe {
    $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($pwsh) { return $pwsh.Source }
    $ps = Get-Command powershell.exe -ErrorAction SilentlyContinue
    if ($ps) { return $ps.Source }
    throw "No se encontro pwsh ni powershell.exe en el PATH."
}

function Resolve-PsqlExe {
    $cmd = Get-Command psql -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($cand in @(
        "C:\Program Files\PostgreSQL\18\bin\psql.exe",
        "C:\Program Files\PostgreSQL\17\bin\psql.exe",
        "C:\Program Files\PostgreSQL\16\bin\psql.exe")) {
        if (Test-Path $cand) { return $cand }
    }
    throw "No se encontro psql en el PATH ni en rutas estandar de PostgreSQL."
}

function New-FoodStoreTask {
    param(
        [string]$Name,
        [string]$Description,
        [string]$Execute,
        [string]$Arguments,
        [object]$Trigger
    )

    $fullName = $Name
    if ($PSCmdlet.ShouldProcess($fullName, "Registrar tarea programada")) {
        $action = New-ScheduledTaskAction -Execute $Execute -Argument $Arguments -WorkingDirectory $ScriptDir
        $principal = New-ScheduledTaskPrincipal -UserId $RunAsUser -LogonType S4U -RunLevel Highest
        $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 2)
        $task = New-ScheduledTask -Action $action -Trigger $Trigger -Principal $principal -Settings $settings -Description $Description
        Register-ScheduledTask -TaskName $fullName -TaskPath $TaskPath -InputObject $task -Force | Out-Null
        Write-Output ("[OK] {0} -> {1} {2}" -f $fullName, $Execute, $Arguments)
    }
}

function Remove-FoodStoreTask {
    param([string]$Name)
    if ($PSCmdlet.ShouldProcess($Name, "Quitar tarea programada")) {
        $existing = Get-ScheduledTask -TaskName $Name -TaskPath $TaskPath -ErrorAction SilentlyContinue
        if ($existing) {
            Unregister-ScheduledTask -TaskName $Name -TaskPath $TaskPath -Confirm:$false
            Write-Output "[OK] Eliminada: $Name"
        } else {
            Write-Output "[INFO] No existe: $Name"
        }
    }
}

$taskNames = @("FoodStore-U6-Backup", "FoodStore-U6-HealthCheck", "FoodStore-U6-Maintenance")
if ($IncludeRestoreDrill -or $Remove) { $taskNames += "FoodStore-U6-RestoreDrill" }

if ($Remove) {
    foreach ($n in $taskNames) { Remove-FoodStoreTask -Name $n }
    Write-Output "Tareas U6 procesadas (eliminacion)."
    exit 0
}

$psExe = Resolve-PowerShellExe
$psqlExe = Resolve-PsqlExe
$backupScript = Join-Path $ScriptDir "backup_foodstore.ps1"
$restoreScript = Join-Path $ScriptDir "restore_test.ps1"
$healthSql = Join-Path $SqlDir "health_check.sql"
$maintSql  = Join-Path $SqlDir "maintenance.sql"

# Respaldo diario 02:00 (SPEC_U6 2.1)
New-FoodStoreTask -Name "FoodStore-U6-Backup" `
    -Description "Respaldo logico diario de $Database (pg_dump -Fc). SPEC_U6: 02:00." `
    -Execute $psExe `
    -Arguments "-NoProfile -ExecutionPolicy Bypass -File `"$backupScript`" -HostName `"$HostName`" -Port $Port -User `"$User`" -Database `"$Database`"" `
    -Trigger (New-ScheduledTaskTrigger -Daily -At 2:00am)

# Health check diario 07:00 (SPEC_U6 2.1)
New-FoodStoreTask -Name "FoodStore-U6-HealthCheck" `
    -Description "Chequeo de salud diario de $Database. SPEC_U6: 07:00." `
    -Execute $psqlExe `
    -Arguments "-h $HostName -p $Port -U $User -d $Database -v ON_ERROR_STOP=1 -f `"$healthSql`"" `
    -Trigger (New-ScheduledTaskTrigger -Daily -At 7:00am)

# Mantenimiento semanal domingo 03:00 (SPEC_U6 2.1)
New-FoodStoreTask -Name "FoodStore-U6-Maintenance" `
    -Description "Revision de mantenimiento semanal (estadisticas/bloat). SPEC_U6: domingo 03:00." `
    -Execute $psqlExe `
    -Arguments "-h $HostName -p $Port -U $User -d $Database -v ON_ERROR_STOP=1 -f `"$maintSql`"" `
    -Trigger (New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 3:00am)

if ($IncludeRestoreDrill) {
    # Simulacro semanal lunes 08:00 (laboratorio, opt-in)
    New-FoodStoreTask -Name "FoodStore-U6-RestoreDrill" `
        -Description "Simulacro de restauracion semanal en base descartable. SPEC_U6: lunes 08:00 (laboratorio)." `
        -Execute $psExe `
        -Arguments "-NoProfile -ExecutionPolicy Bypass -File `"$restoreScript`" -HostName `"$HostName`" -Port $Port -User `"$User`" -Database `"$Database`"" `
        -Trigger (New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At 8:00am)
}

Write-Output ""
Write-Output "Resumen:"
Write-Output "  Ruta de tareas : $TaskPath"
Write-Output "  Cuenta         : $RunAsUser (S4U; requiere pgpass.conf para esa cuenta)"
Write-Output "  psql           : $psqlExe"
Write-Output "  PowerShell     : $psExe"
Write-Output ""
Write-Output "Verificar:  Get-ScheduledTask -TaskPath '$TaskPath' | Format-Table TaskName,State"
Write-Output "Ejecutar:   Start-ScheduledTask -TaskPath '$TaskPath' -TaskName 'FoodStore-U6-Backup'"
Write-Output "Quitar:     .\schedule_u6.ps1 -Remove [-IncludeRestoreDrill]"
Write-Output ""
Write-Output "Nota: el simulacro de restauracion no se registra por defecto; use -IncludeRestoreDrill si aplica."
