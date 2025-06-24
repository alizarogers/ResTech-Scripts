param (
    $name,
    [switch]$h
)

#Windows 11 Requirements
$rqdProcessorSpeed = 1000 #Hz
$rqdCores = 2 
$rqdMemory = 4294967296 #bytes
$rqdStorage = 68719476736 #bytes
$rqdFirmware = "UEFI"
 
 
function get-specs {

        $systemdrive = Get-WmiObject -Class Win32_OperatingSystem | Select-Object -ExpandProperty SystemDrive

        $results = `
        #processor and memory
        (Get-ComputerInfo | Select-Object CsProcessors, CsTotalPhysicalMemory), `

        # TPM
        (Get-Tpm | Select-Object ManufacturerVersionFull20), `

        # Storage
        (Get-WmiObject Win32_LogicalDisk | Where-Object {$_.DeviceID -eq $systemdrive}), `

        #Firmware
        ($env:firmware_type) 
    return $results
}

function has-compatible-processor {
    
    param (
        [Parameter(Mandatory = $true)][PSCustomObject]$processor

    )
    
    # enumerated types for processor architecture
    $arm64 = 12
    $x64 = 9
    $x86 = 0

    if (($processor.Architecture -eq $x64) -or ($processor.Architecture -eq $x86)) {
        if ($processor.Manufacturer -eq "GenuineIntel") {

            # Find the exceptions below
                if ($processor.Description -match "Family (\d) Model (\d*)( Stepping )?(\d*)?") {
                    $family = [int]$matches[1]
                    $model = [int]$matches[2]
                    if ($matches.Count -gt 3) { $stepping = [int]$matches[4] } else { $stepping = 0 }

                    # if family >= 6 and model <=95, not compatible 
                    # except for family = 6 and model = 85, that is supported
                    if ((($family -ge 6) -and ($model -le 95)) -and (-not ($family -eq 6 -and $model -eq 85))) {
                        return $false

                        # if family = 6, model is 142, stepping 9, and registry is not 16, not supported
                        # if family = 6, model is 158, stepping 9, and registry is not 8, not supported
                    }
                    elseif ( $family -eq 6 -and ($model -eq 142 -or $model -eq 158) -and $stepping -eq 9) {
                        #  $regValue = Invoke-Command -ComputerName $name -ScriptBlock { Get-ItemPropertyValue -Path HKLM:\HARDWARE\DESCRIPTION\System\CentralProcessor\0 -Name "Platform Specific Field 1" }
                        $regValue = $(Get-ItemPropertyValue -Path HKLM:\HARDWARE\DESCRIPTION\System\CentralProcessor\0 -Name "Platform Specific Field 1") 
                        if ((($model -eq 142) -and ($regValue -ne 16)) -or (($model -eq 158) -and ($regValue -ne 8))) {
                            return $false
                        }
                    }
                }
        }
        elseif ($processor.Manufacturer -eq "AuthenticAMD") {
         
            # come back to this later
            # everything except for family < 23 or (cpu = 23 & model 1 or 17)
        }
    }
    else {
        # If not x86 or 64, assume no
        return $false
    }
} 

$specs = get-specs -name $name


$processorMeetsReq = ($specs[0].CsProcessors.MaxClockSpeed -ge $rqdProcessorSpeed) -and ($specs[0].CsProcessors.NumberofCores -ge $rqdCores)
$processorMeetsReq = $processorMeetsReq -and (has-compatible-processor -processor $processor.CsProcessors)
$memoryMeetsReq = ($specs[0].CsTotalPhysicalMemory -ge $rqdMemory)
$tpmMeetsReq = -not ($specs[1] -match "Not Supported")
$storeageMeetReq = $specs[2].Size -ge $rqdStorage
$firmwareMeetReq = $specs[3] -match "UEFI"
$isEligable = $tpmMeetsReq -and $storeageMeetReq -and $firmwareMeetReq -and $memoryMeetsReq -and $processorMeetsReq

Write-Host "T/F, this is eligible for Windows 11 "
Write-Host $isEligable