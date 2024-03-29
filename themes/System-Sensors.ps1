function Global:Get-SensorCim {
    $NameSpace   = "root/LibreHardwareMonitor"
    $Hardware = Get-CimInstance -Namespace $NameSpace -ClassName Hardware | Select-Object Name,
    HardwareType,
    @{name = "Identifier";expression = {$_.Identifier -replace "\\|\?"}}
    $Sensors = Get-CimInstance -Namespace $NameSpace -ClassName Sensor 
    $Sensors = $Sensors | Select-Object @{
        name = "HardwareName"
        expression = {
            $Parent = $_.Parent -replace "\\|\?"
            $Hardware | Where-Object Identifier -match $Parent | Select-Object -ExpandProperty Name
        }
    },
    @{name = "SensorName";expression = { $_.Name }},
    @{name = "SensorType";expression = { "$($_.SensorType) $($_.Index)" }},
    @{name = "Value";expression = { [int]$_.Value }},
    @{name = "Min";expression = { [int]$_.Min }},
    @{name = "Max";expression = { [int]$_.Max }}
    $Sensors | Sort-Object HardwareName,SensorType,SensorName
}

function Global:Set-EnvVariable {
    $Sensors = Get-SensorCim
    $CPU_TEMP_PACKAGE = $Sensors | Where-Object {($_.SensorName -eq "CPU Package") -and ($_.SensorType -match "Temperature")}
    $CPU_LOAD_TOTAL   = $Sensors | Where-Object {($_.SensorName -eq "CPU Total") -and ($_.SensorType -match "Load")}
    $NET_UPLOAD_SPEED = $(
        $Sensors | Where-Object {
            ($_.SensorName -match "Upload") -and (($_.SensorType -match "Throughput") -and ($_.Value -ne 0))
        } | Sort-Object -Property Value -Descending
    )
    $NET_DOWNLOAD_SPEED = $(
        $Sensors | Where-Object {
            ($_.SensorName -match "Download") -and (($_.SensorType -match "Throughput") -and ($_.Value -ne 0))
        } | Sort-Object -Property Value -Descending
    )
    if ($null -eq $NET_UPLOAD_SPEED) {
        $NET_UPLOAD_SPEED = "0,000"
    } else {
        $NET_UPLOAD_SPEED = $($NET_UPLOAD_SPEED[0].Value/1mb).ToString("0.000")
    }
    if ($null -eq $NET_DOWNLOAD_SPEED) {
        $NET_DOWNLOAD_SPEED = "0,000"
    } else {
        $NET_DOWNLOAD_SPEED = $($NET_DOWNLOAD_SPEED[0].Value/1mb).ToString("0.000")
    }
    $env:SENSOR_CPU_TEMP_VALUE = $CPU_TEMP_PACKAGE.Value
    $env:SENSOR_CPU_TEMP_MIN   = $CPU_TEMP_PACKAGE.Min
    $env:SENSOR_CPU_TEMP_MAX   = $CPU_TEMP_PACKAGE.Max
    $env:SENSOR_CPU_LOAD_VALUE = $CPU_LOAD_TOTAL.Value
    $env:SENSOR_CPU_LOAD_MIN   = $CPU_LOAD_TOTAL.Min
    $env:SENSOR_CPU_LOAD_MAX   = $CPU_LOAD_TOTAL.Max
    $env:SENSOR_MEM_UPLOAD     = $NET_UPLOAD_SPEED
    $env:SENSOR_MEM_DOWNLOAD   = $NET_DOWNLOAD_SPEED
}

New-Alias -Name "Set-PoshContext" -Value "Set-EnvVariable" -Scope Global -Force

oh-my-posh init pwsh --config "https://raw.githubusercontent.com/Lifailon/oh-my-posh-themes/rsa/themes/System-Sensors.omp.json" | Invoke-Expression
