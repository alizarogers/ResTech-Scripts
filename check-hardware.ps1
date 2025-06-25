param (
    [switch]$object
)
#Windows 11 Requirements
$rqdProcessorSpeed = 1000 #Hz
$rqdCores = 2 
$rqdMemory = 4294967296 #bytes
$rqdStorage = 68719476736 #bytes
$rqdFirmware = "UEFI"
 
function get-specs {
        
    $systemdrive = Get-WmiObject -Class Win32_OperatingSystem | Select-Object -ExpandProperty SystemDrive

    $computerInfo = $(Get-ComputerInfo | Select-Object CsProcessors, CsTotalPhysicalMemory, BiosFirmwareType)

    $tpm = $(Get-Tpm | Select-Object ManufacturerVersionFull20)

    $storage = $(Get-WmiObject Win32_LogicalDisk | Where-Object { $_.DeviceID -eq $systemdrive })
    
    $results = [PSCustomObject]@{
        Processor = $computerInfo.CsProcessors[0]
        Memory = $computerInfo.CsTotalPhysicalMemory
        TPM = $tpm.ManufacturerVersionFull20
        Storage = $storage.Size
        Firmware = $computerInfo.BiosFirmwareType
    }

    return $results
}

function Test-ProcessorCompatibility {
    
    param (
        [Parameter(Mandatory = $true)][PSCustomObject]$processor

    )
    
    # enumerated types for processor architecture
    # $arm64 = 12
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

$specs = get-specs


$processorMeetsReq = ($specs.Processor.MaxClockSpeed -ge $rqdProcessorSpeed) -and ($specs.Processor.NumberofCores -ge $rqdCores)
$processorCompatible = Test-ProcessorCompatibility -processor $specs.Processor
$memoryMeetsReq = ($specs.Memory -ge $rqdMemory)
$tpmMeetsReq = -not ($specs.TPM -match "Not Supported")
$storeageMeetReq = $specs.Storage -ge $rqdStorage
$firmwareMeetReq = $specs.Firmware -match $rqdFirmware

$requirements = [PSCustomObject]@{
    Storage = $storeageMeetReq
    TPM = $tpmMeetsReq
    Firmware = $firmwareMeetReq
    Memory = $memoryMeetsReq
    Processor = $processorMeetsReq -and $processorCompatible
}

$requirements | Out-String | Write-Verbose -Verbose

if ($object)
{
    return $object
} else {
    Write-Host $($processorMeetsReq -and $processorCompatible -and $memoryMeetsReq -and $tpmMeetsReq -and $storeageMeetReq -and $firmwareMeetReq)
}
