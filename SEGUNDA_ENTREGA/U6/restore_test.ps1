<#
.SYNOPSIS
    Script automatizable de simulacro de recuperacion y medicion de RTO/RPO.
.DESCRIPTION
    Restaura el ultimo volcado de foodStore en la base descartable foodstore_restore_test,
    cronometra el RTO (tiempo de recuperacion), calcula el RPO (antiguedad de la copia),
    y ejecuta las validaciones de consistencia logica requeridas.
.NOTES
    Materia: Bases de Datos II - Tecnicatura Universitaria en Programacion
    Unidad 6: Mantenimiento, respaldo y recuperacion
#>

[CmdletBinding()]
param(
    [string]$HostName = "localhost",
    [int]$Port = 5432,
    [string]$User = "postgres",
    [string]$TestDatabase = "foodstore_restore_test",
    [string]$DumpPath = ""
)

# Configurar encoding UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Determinar directorios del script
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $ScriptDir) { $ScriptDir = Get-Location }

$BackupsDir = Join-Path $ScriptDir "backups"
$LogsDir    = Join-Path $ScriptDir "logs"
$SqlDir     = Join-Path $ScriptDir "sql"

if (-not (Test-Path $LogsDir)) { New-Item -ItemType Directory -Path $LogsDir -Force | Out-Null }

$DateStamp = Get-Date -Format "yyyy-MM-dd"
$LogFile   = Join-Path $LogsDir "restore_test_$DateStamp.log"

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
Write-Log "INICIO DE SIMULACRO DE DESASTRE Y RESTAURACION"
Write-Log ("Servidor: {0}:{1} | Usuario: {2} | Base Descartable: {3}" -f $HostName, $Port, $User, $TestDatabase)

# 1. Localizar binarios de PostgreSQL 18
$PgBinDir = $null
$pgCmd = Get-Command pg_restore -ErrorAction SilentlyContinue
if ($pgCmd) {
    $PgBinDir = Split-Path -Parent $pgCmd.Source
} else {
    $candidateDirs = @(
        "C:\Program Files\PostgreSQL\18\bin",
        "C:\Program Files\PostgreSQL\17\bin",
        "C:\Program Files\PostgreSQL\16\bin"
    )
    foreach ($d in $candidateDirs) {
        $probe = Join-Path $d "pg_restore.exe"
        if (Test-Path $probe) {
            $PgBinDir = $d
            break
        }
    }
}

if (-not $PgBinDir -or -not (Test-Path $PgBinDir)) {
    Write-Log "ERROR CRITICO: No se encontro el directorio bin de PostgreSQL en las rutas estandar." "ERROR"
    exit 1
}

$PgRestoreBin = Join-Path $PgBinDir "pg_restore.exe"
$CreatedbBin  = Join-Path $PgBinDir "createdb.exe"
$DropdbBin    = Join-Path $PgBinDir "dropdb.exe"
$PsqlBin      = Join-Path $PgBinDir "psql.exe"

Write-Log ("Directorio binario PostgreSQL detectado: {0}" -f $PgBinDir)

# 2. Identificar el archivo de volcado (.dump)
$TargetDump = $null
if ($DumpPath -and (Test-Path $DumpPath)) {
    $TargetDump = Get-Item $DumpPath
} else {
    $DumpFiles = Get-ChildItem -Path $BackupsDir -Filter "*.dump" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
    if ($DumpFiles -and $DumpFiles.Count -gt 0) {
        $TargetDump = $DumpFiles[0]
    }
}

if (-not $TargetDump -or -not (Test-Path $TargetDump.FullName)) {
    Write-Log "ERROR: No se encontro ningun archivo de volcado .dump en 'backups/' para restaurar." "ERROR"
    exit 1
}

$DumpFileName = $TargetDump.Name
$DumpFileSizeKB = [Math]::Round(($TargetDump.Length / 1024), 2)
$DumpFileTime = $TargetDump.LastWriteTime

Write-Log ("Volcado seleccionado: {0} ({1} KB)" -f $TargetDump.FullName, $DumpFileSizeKB)
Write-Log ("Fecha de generacion del volcado: {0}" -f $DumpFileTime.ToString("yyyy-MM-dd HH:mm:ss"))

# 3. Gestion segura de credenciales
$PgPassPath = Join-Path $env:APPDATA "postgresql\pgpass.conf"
$CleanEnvAfterRun = $false

if (-not $env:PGPASSWORD -and -not (Test-Path $PgPassPath)) {
    Write-Host "`n[SEGURIDAD] No se detecto variable `$env:PGPASSWORD ni archivo pgpass.conf." -ForegroundColor Yellow
    Write-Host "Ingrese la contrasena para '$User' (el texto no se mostrara en pantalla):" -ForegroundColor Yellow
    $SecurePassword = Read-Host -AsSecureString
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
    $env:PGPASSWORD = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
    $CleanEnvAfterRun = $true
}

# 4. Helper de ejecucion de comandos CLI con argumentos escapados
function Execute-CliCommand {
    param (
        [string]$Binary,
        [string[]]$ArgsList
    )
    $escaped = foreach ($a in $ArgsList) {
        $s = [string]$a
        if ($s -match '\s' -and -not ($s.StartsWith('"') -and $s.EndsWith('"'))) {
            '"{0}"' -f $s
        } else {
            $s
        }
    }
    $pInfo = New-Object System.Diagnostics.ProcessStartInfo
    $pInfo.FileName = $Binary
    $pInfo.Arguments = ($escaped -join " ")
    $pInfo.RedirectStandardOutput = $true
    $pInfo.RedirectStandardError = $true
    $pInfo.UseShellExecute = $false
    $pInfo.CreateNoWindow = $true

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $pInfo
    $proc.Start() | Out-Null
    $outText = $proc.StandardOutput.ReadToEnd()
    $errText = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()

    return @{
        ExitCode = $proc.ExitCode
        StdOut   = $outText
        StdErr   = $errText
    }
}

# 5. INICIO DE CRONOMETRO DE RECUPERACION (RTO)
$DrillStartTime = Get-Date
$RtoStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
Write-Log ">>> [CRONOMETRO RTO INICIADO] <<<"

# Calculo de RPO (antiguedad de la copia)
$RpoSpan = $DrillStartTime - $DumpFileTime
$RpoHours = [int]$RpoSpan.TotalHours
$RpoMins  = $RpoSpan.Minutes
$RpoSecs  = $RpoSpan.Seconds
$RpoFormatted = ("{0:D2}h {1:D2}m {2:D2}s" -f $RpoHours, $RpoMins, $RpoSecs)
Write-Log ("RPO Calculado (Antiguedad del respaldo): {0}" -f $RpoFormatted)

# PASO A: Limpieza de base descartable si ya existia
Write-Log "Paso 1: Limpiando base descartable previa '$TestDatabase'..."
$resDrop = Execute-CliCommand -Binary $DropdbBin -ArgsList @("-h", $HostName, "-p", $Port, "-U", $User, "--if-exists", $TestDatabase)
if ($resDrop.StdErr) { Add-Content -Path $LogFile -Value $resDrop.StdErr -Encoding UTF8 }

# PASO B: Creacion de base descartable limpia
Write-Log "Paso 2: Creando base descartable '$TestDatabase'..."
$resCreate = Execute-CliCommand -Binary $CreatedbBin -ArgsList @("-h", $HostName, "-p", $Port, "-U", $User, $TestDatabase)
if ($resCreate.ExitCode -ne 0) {
    Write-Log ("ERROR al crear la base '{0}': {1}" -f $TestDatabase, $resCreate.StdErr) "ERROR"
    if ($CleanEnvAfterRun) { Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue }
    exit 1
}

# PASO C: Restauracion con pg_restore (--no-owner --no-privileges)
Write-Log "Paso 3: Restaurando con pg_restore (--no-owner --no-privileges)..."
$restoreArgs = @(
    "-h", $HostName,
    "-p", $Port,
    "-U", $User,
    "-d", $TestDatabase,
    "--no-owner",
    "--no-privileges",
    "-v",
    $TargetDump.FullName
)
$resRestore = Execute-CliCommand -Binary $PgRestoreBin -ArgsList $restoreArgs
if ($resRestore.StdOut) { Add-Content -Path $LogFile -Value $resRestore.StdOut -Encoding UTF8 }
if ($resRestore.StdErr) { Add-Content -Path $LogFile -Value $resRestore.StdErr -Encoding UTF8 }

if ($resRestore.ExitCode -gt 1) {
    Write-Log ("ERROR FATAL durante pg_restore: Codigo {0}" -f $resRestore.ExitCode) "ERROR"
    if ($CleanEnvAfterRun) { Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue }
    exit 1
}

# PASO D: Validaciones minimas del TP
Write-Log "Paso 4: Ejecutando validaciones logicas de integridad..."
$ValidationSql = Join-Path $SqlDir "validation_drill.sql"
$psqlArgs = @(
    "-h", $HostName,
    "-p", $Port,
    "-U", $User,
    "-d", $TestDatabase,
    "-f", $ValidationSql
)
$resVal = Execute-CliCommand -Binary $PsqlBin -ArgsList $psqlArgs

if ($resVal.StdOut) {
    Write-Log "--- RESULTADOS DE VALIDACION ---"
    Write-Output $resVal.StdOut
    Add-Content -Path $LogFile -Value $resVal.StdOut -Encoding UTF8
}
if ($resVal.StdErr) {
    Add-Content -Path $LogFile -Value $resVal.StdErr -Encoding UTF8
}

# 6. FIN DE CRONOMETRO DE RECUPERACION (RTO)
$RtoStopwatch.Stop()
$RtoSeconds = [Math]::Round($RtoStopwatch.Elapsed.TotalSeconds, 2)
Write-Log ">>> [CRONOMETRO RTO FINALIZADO] <<<"

# Limpieza de contrasena en memoria
if ($CleanEnvAfterRun) {
    Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
}

# 7. Resumen Ejecutivo
Write-Log "================================================================="
Write-Log "INFORME EJECUTIVO DEL SIMULACRO DE DESASTRE"
Write-Log ("Respaldo utilizado: {0}" -f $DumpFileName)
Write-Log ("Fecha de respaldo:  {0}" -f $DumpFileTime.ToString("yyyy-MM-dd HH:mm:ss"))
Write-Log ("Fecha de simulacro: {0}" -f $DrillStartTime.ToString("yyyy-MM-dd HH:mm:ss"))
Write-Log ("RPO Observado:      {0} (Antiguedad de la copia)" -f $RpoFormatted)
Write-Log ("RTO Medido:         {0} segundos (Meta: < 300 s)" -f $RtoSeconds)

if ($resVal.ExitCode -eq 0) {
    Write-Log "ESTADO DEL SIMULACRO: RECUPERACION EXITOSA Y VALIDADA"
    Write-Log ("Traza completa archivada en: {0}" -f $LogFile)
    Write-Log "================================================================="
    exit 0
} else {
    Write-Log "ESTADO DEL SIMULACRO: FALLO LA VALIDACION LOGICA" "ERROR"
    Write-Log "================================================================="
    exit 1
}
