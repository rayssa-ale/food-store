<#
.SYNOPSIS
    Script automatizable de respaldo lógico para la base de datos foodstore.
.DESCRIPTION
    Realiza un respaldo completo en formato custom (-Fc) utilizando pg_dump de PostgreSQL 18.
    Genera logs detallados en la carpeta logs/ y almacena los volcados en backups/ con estampa temporal.
    Cumple con las restricciones de seguridad: no expone contraseñas en texto claro.
.NOTES
    Materia: Bases de Datos II - Tecnicatura Universitaria en Programación
    Unidad 6: Mantenimiento, respaldo y recuperación
#>

[CmdletBinding()]
param(
    [string]$HostName = "localhost",
    [int]$Port = 5432,
    [string]$User = "postgres",
    [string]$Database = "foodStore"
)

# Configurar encoding para caracteres especiales
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Determinar directorios de trabajo basados en la ubicación del script
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $ScriptDir) { $ScriptDir = Get-Location }

$BackupsDir = Join-Path $ScriptDir "backups"
$LogsDir    = Join-Path $ScriptDir "logs"

# Asegurar existencia de directorios
if (-not (Test-Path $BackupsDir)) { New-Item -ItemType Directory -Path $BackupsDir -Force | Out-Null }
if (-not (Test-Path $LogsDir))    { New-Item -ItemType Directory -Path $LogsDir -Force | Out-Null }

# Definir marcas temporales
$Timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
$DateStamp = Get-Date -Format "yyyy-MM-dd"

# Rutas de archivos de salida
$DumpFile = Join-Path $BackupsDir "${Database}_$Timestamp.dump"
$LogFile  = Join-Path $LogsDir "backup_${Database}_$DateStamp.log"

# Función interna de logging
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $LogEntry = "[{0}] [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
    Write-Output $LogEntry
    Add-Content -Path $LogFile -Value $LogEntry -Encoding UTF8
}

Write-Log "================================================================="
Write-Log "INICIO DE PROCESO DE RESPALDO: $Database"
Write-Log ("Servidor: {0}:{1} | Usuario: {2} | Formato: Custom (-Fc)" -f $HostName, $Port, $User)

# 1. Localizar binario pg_dump de PostgreSQL 18
$PgDumpPath = $null
$PgDumpCmd = Get-Command pg_dump -ErrorAction SilentlyContinue
if ($PgDumpCmd) {
    $PgDumpPath = $PgDumpCmd.Source
}

if (-not $PgDumpPath) {
    $Candidates = @(
        "C:\Program Files\PostgreSQL\18\bin\pg_dump.exe",
        "C:\Program Files\PostgreSQL\17\bin\pg_dump.exe",
        "C:\Program Files\PostgreSQL\16\bin\pg_dump.exe"
    )
    foreach ($cand in $Candidates) {
        if (Test-Path $cand) {
            $PgDumpPath = $cand
            break
        }
    }
}

if (-not $PgDumpPath -or -not (Test-Path $PgDumpPath)) {
    Write-Log "ERROR CRÍTICO: No se encontró el ejecutable pg_dump en el PATH ni en rutas estándar de PostgreSQL." "ERROR"
    exit 1
}

Write-Log "Binario pg_dump detectado: $PgDumpPath"

# 2. Gestión segura de credenciales (sin exponer contraseña)
$PgPassPath = Join-Path $env:APPDATA "postgresql\pgpass.conf"
$CleanEnvAfterRun = $false

if (-not $env:PGPASSWORD -and -not (Test-Path $PgPassPath)) {
    Write-Host "`n[SEGURIDAD] No se detectó variable `$env:PGPASSWORD ni archivo pgpass.conf." -ForegroundColor Yellow
    Write-Host "Ingrese la contraseña para '$User' (el texto no se mostrará en pantalla):" -ForegroundColor Yellow
    $SecurePassword = Read-Host -AsSecureString
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
    $env:PGPASSWORD = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
    $CleanEnvAfterRun = $true
}

# 3. Ejecución del respaldo con pg_dump
Write-Log "Generando respaldo custom en: $DumpFile"
$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

# Argumentos para pg_dump
$DumpArgs = @(
    "-h", $HostName,
    "-p", $Port,
    "-U", $User,
    "-d", $Database,
    "-Fc",
    "-v",
    "-f", $DumpFile
)

# Escapar argumentos que contengan espacios para evitar fragmentación en la línea de comandos
$EscapedArgs = foreach ($arg in $DumpArgs) {
    $str = [string]$arg
    if ($str -match '\s' -and -not ($str.StartsWith('"') -and $str.EndsWith('"'))) {
        '"{0}"' -f $str
    } else {
        $str
    }
}

# Ejecutar proceso capturando salida y errores
$ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
$ProcessInfo.FileName = $PgDumpPath
$ProcessInfo.Arguments = ($EscapedArgs -join " ")
$ProcessInfo.RedirectStandardError = $true
$ProcessInfo.RedirectStandardOutput = $true
$ProcessInfo.UseShellExecute = $false
$ProcessInfo.CreateNoWindow = $true

$Process = New-Object System.Diagnostics.Process
$Process.StartInfo = $ProcessInfo

$Process.Start() | Out-Null

$StdOut = $Process.StandardOutput.ReadToEnd()
$StdErr = $Process.StandardError.ReadToEnd()
$Process.WaitForExit()

$ExitCode = $Process.ExitCode
$Stopwatch.Stop()

# Registrar traza detallada de pg_dump en el log
if ($StdOut) {
    Add-Content -Path $LogFile -Value $StdOut -Encoding UTF8
}
if ($StdErr) {
    Add-Content -Path $LogFile -Value $StdErr -Encoding UTF8
}

# 4. Limpieza de credencial en memoria si fue solicitada interactivamente
if ($CleanEnvAfterRun) {
    Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
}

# 5. Validación de resultado y código de salida
if ($ExitCode -eq 0 -and (Test-Path $DumpFile) -and ((Get-Item $DumpFile).Length -gt 0)) {
    $FileSize = (Get-Item $DumpFile).Length
    $FileSizeKB = [Math]::Round($FileSize / 1KB, 2)
    $DurationSec = [Math]::Round($Stopwatch.Elapsed.TotalSeconds, 2)

    Write-Log "RESPALDO EXITOSO: Código de salida 0"
    Write-Log "Archivo generado: $DumpFile ($FileSizeKB KB)"
    Write-Log "Tiempo transcurrido: $DurationSec segundos"
    Write-Log "Log guardado en: $LogFile"
    Write-Log "================================================================="
    exit 0
} else {
    Write-Log "ERROR: El respaldo falló con código de salida: $ExitCode" "ERROR"
    if (Test-Path $DumpFile) {
        if ((Get-Item $DumpFile).Length -eq 0) {
            Write-Log "ERROR: El archivo de volcado se generó con 0 bytes (archivo vacío)." "ERROR"
            Remove-Item -Path $DumpFile -Force -ErrorAction SilentlyContinue
        }
    } else {
        Write-Log "ERROR: No se generó el archivo de volcado esperado." "ERROR"
    }
    Write-Log "Revise los detalles de error en el log: $LogFile" "ERROR"
    Write-Log "================================================================="
    exit 1
}
