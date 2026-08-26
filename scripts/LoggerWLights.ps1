# TempLogger.ps1
# Logs SHT31 readings from RP2040 every 5 seconds
# Saves CSVs to Downloads\TempLogs

$rp2040 = Get-CimInstance Win32_SerialPort |
    Where-Object { $_.PNPDeviceID -match "VID_2E8A" } |
    Select-Object -First 1

if (-not $rp2040)
{
    Write-Host "RP2040 device not found." -ForegroundColor Red
    Start-Sleep -Seconds 5
    return
}

$portName = $rp2040.DeviceID
Write-Host "Using port: $portName"

$logFolder = Join-Path $HOME "Downloads\TempLogs"
#$logFolder = "D:\Scripts\TempLogs"

if (!(Test-Path $logFolder))
{
    New-Item -ItemType Directory -Path $logFolder -Force | Out-Null
}

$sessionTime = Get-Date -Format "yyyy-MM-dd_HHmmss"
$csvFile = Join-Path $logFolder "TempHum_$sessionTime.csv"

$serial = $null

try
{
    $serial = New-Object System.IO.Ports.SerialPort $portName,115200,None,8,one
    $serial.ReadTimeout = 5000
    $serial.WriteTimeout = 5000
    $serial.Open()

    Start-Sleep -Seconds 2

    $serial.WriteLine('{"cmd":"start_session"}')
    $line = $serial.ReadLine()
    $obj = $line | ConvertFrom-Json

    if ($obj.message -ne "SESSION_STARTED")
    {
        throw "Failed to start RP2040 session. Response was: $line"
    }

    function Get-SensorReading {
        param($sp)

        $sp.WriteLine('{"cmd":"read_sensor"}')

        while ($true)
        {
            $line = $sp.ReadLine()
            $obj = $line | ConvertFrom-Json

            if ($obj.type -eq 'sensor') { return $obj }
            elseif ($obj.type -eq 'error')
            {
                Write-Host "RP2040 ERROR: $($obj.message)"
            }
        }
    }

    function Export-ReadingToCsv {
        param(
            [Parameter(Mandatory=$true)] $SensorObj,
            [Parameter(Mandatory=$true)] $FilePath
        )

        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $tempF = [Math]::Round(([double]$SensorObj.temp_c * 9 / 5) + 32, 1)

        $logData = [PSCustomObject]@{
            Timestamp       = $timestamp
            TemperatureC    = $SensorObj.temp_c
            TemperatureF    = $tempF
            HumidityPercent = $SensorObj.humidity
        }

        $logData | Export-Csv -Path $FilePath -Append -NoTypeInformation -UseCulture -Encoding utf8

        return $tempF
    }

    $firstObj = Get-SensorReading $serial
    $tempF = Export-ReadingToCsv -SensorObj $firstObj -FilePath $csvFile

    Write-Host "Logging started"
    Write-Host ("Temp: {0} C ({1} F) RH: {2} %%" -f $firstObj.temp_c, $tempF, $firstObj.humidity)
    Write-Host ""
    Write-Host "CSV:"
    Write-Host $csvFile
    Write-Host ""
    Write-Host "Press Y to turn LEDs on."
    Write-Host "Press N to turn LEDs off."

    $nextRead = (Get-Date).AddSeconds(5)

    while ($true)
    {
        if ((Get-Date) -ge $nextRead)
        {
            $obj = Get-SensorReading $serial
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $tempF = Export-ReadingToCsv -SensorObj $obj -FilePath $csvFile

            Write-Host ("[{0}] Temp: {1} C ({2} F) RH: {3} %%" -f $timestamp, $obj.temp_c, $tempF, $obj.humidity)

            $nextRead = (Get-Date).AddSeconds(5)
        }

        if ([Console]::KeyAvailable)
        {
            $key = [Console]::ReadKey($true)

            if ($key.Key -eq [ConsoleKey]::Y)
            {
                $serial.WriteLine('{"cmd":"light_on"}')
                Write-Host "LEDs ON"
            }
            elseif ($key.Key -eq [ConsoleKey]::N)
            {
                $serial.WriteLine('{"cmd":"light_off"}')
                Write-Host "LEDs OFF"
            }
        }

        Start-Sleep -Milliseconds 100
    }
}
catch
{
    Write-Host ""
    Write-Host "ERROR OCCURRED" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "Closing in 5 seconds..." -ForegroundColor Yellow
    Write-Host ""

    Start-Sleep -Seconds 5
}
finally
{
    if ($serial -and $serial.IsOpen)
    {
        $serial.Close()
    }

    Write-Host "CSV saved: $csvFile"
}
