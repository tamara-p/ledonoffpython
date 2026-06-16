$port = "COM4"

$serial = New-Object System.IO.Ports.SerialPort $port,115200,None,8,one
$serial.Open()

Start-Sleep -Seconds 2  # give RP2040 time to boot

Write-Host "Type Y to turn LEDs ON. Anything else = OFF"

while ($true) {
    $input = Read-Host "Enter command"

    if ($input -eq "Y") {
        $serial.Write("Y")
    } else {
        $serial.Write("N")
    }
}