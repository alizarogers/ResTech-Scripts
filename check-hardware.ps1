param (
    [Parameter(Mandatory=$true)]$name,
    [switch]$h
)

#Windows 11 Requirements

$rqdProcessorSpeed = 1000 #Hz
$rqdCores = 2 
$rqdMemory = 4294967296 #bytes
$rqdStorage = 68719476736 #bytes
$rqdFirmware = "UEFI"
         

function get-specs {
    param (
        $name
    )

    $results = Invoke-Command -ComputerName $name -ScriptBlock{ `

        $systemdrive = Get-WmiObject -Class Win32_OperatingSystem | Select-Object -ExpandProperty SystemDrive

        #processor and memory
        (Get-ComputerInfo | Select-Object CsProcessors, CsTotalPhysicalMemory), `

        # TPM
        (Get-Tpm | Select-Object -ExpandProperty ManufacturerVersionFull20), `

        # Storage
        (Get-WmiObject Win32_LogicalDisk | Where-Object {$_.DeviceID -eq $systemdrive}),

        #Firmware
        ($env:firmware_type) }

    Write-Host $results

    return $results
}

$specs = get-specs -name $name

# loop to check each
#$processorMeetsReq = ($specs[0].CsProcessors.MaxClockSpeed -ge $rqdProcessorSpeed) -and ($processors[0].CsProcessors.NumberofCores -ge $rqdCores)

#$memoryMeetsReq = ($specs[0].CsTotalPhysicalMemory -ge $rqdMemory)

# TPM
$tpmMeetsReq = -not ($specs[1] -match "Not Supported")


#Storage 
$storeageMeetReq = $specs[2].Size -ge $rqdStorage

#Firmware
$firmwareMeetReq = $specs[3] -match "UEFI"

$isEligable = $tpmMeetsReq -and $storeageMeetReq -and $firmwareMeetReq

Write-Host "T/F, this is eligible for Windows 11 "
Write-Host $isEligable