# Find active RP2040 COM port using VID
$rp2040 = Get-CimInstance Win32_SerialPort |
    Where-Object {
        $_.PNPDeviceID -match "VID_2E8A"
    } |
    Select-Object -First 1

if (-not $rp2040) {
    Write-Host "RP2040 device not found."
    exit
}

$port = $rp2040.DeviceID  # already like "COM5"

Write-Host "Using port: $port"

# Serial setup (unchanged)
$serial = New-Object System.IO.Ports.SerialPort $port,115200,None,8,one
$serial.Open()

Start-Sleep -Seconds 2

Write-Host "Type Y to turn LEDs ON. Anything else = OFF"

while ($true) {
    $input = Read-Host "Enter command"

    if ($input -eq "Y") {
        $serial.Write("Y")
    } else {
        $serial.Write("N")
    }
}