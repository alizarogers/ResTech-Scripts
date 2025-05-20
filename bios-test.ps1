#Requires -RunAsAdministrator

param 
(
    $name
)
    
$ErrorActionPreference = "Stop"

$TPM20 = @("1.3.2.8",'7\.2(.*)',"74.8.17568.5511")
$TPM12 = @("5.81")

function Check-Online-Status {
    param (
        $name
    )

    $result = ping $name

    
    if ($result[2] -match "(\d+\.?)+") { # if the ping returned a reply

        $machineIP = $matches[0]
        
        if ($result[1] -match $machineIP) {  # reply & machine IP address match

            $message = $name + " is online. Proceeding to check machine information.`n"
            Write-Host $message

        } else { # addresses do not match

            $message = $name + " is online, but the reply IP address did not match the machine IP address."
            Write-Host $message
            Exit
        }

    } else { # if the ping was not successful

        if ($result[2] -match "Request timed out.") {
            $message = $name + " is offline."

        } elseif ($result -match "could not find host") {
            $message = $name + " host could not be found."

        } else {
            $message = "Something went wrong while pinging the machine."
        }
        Write-Host $message
        Exit
    }
}

function Get-Machine-Information {
    param (
        $name
    )
    $results = Invoke-Command -ComputerName $name -ScriptBlock{ `

        # Windows Version, BIOS Version, Model of the Machine
        (Get-ComputerInfo | Select-Object OsName, BiosSMBIOSBIOSVersion, CsModel, CsName), `

        # TPM Information
        (Get-Tpm | Select-Object TpmPresent, TpmEnabled, ManufacturerVersion), `
    
        # Asset Tag
        (Get-WmiObject Win32_SystemEnclosure | Select-Object -ExpandProperty SMBIOSAssetTag), `

        # RAID
        (Get-WmiObject -Class Win32_SCSIController | Where-Object {$_.DriverName -eq "iaStorAC"}), `

        # Bitlocker
        (Get-BitLockerVolume | Select-Object -ExpandProperty VolumeStatus), `
    
        # SecureBoot
        (Confirm-SecureBootUEFI)} 
           
    foreach ($result in $results) {
        $message = $result + '`n'
        Write-Host $message
    }

    return $results
}

function Build-Information-Object {
    param(
        $machineInfo # the object returned from Get-Machine-Information
    )

    $Info_object = [pscustomobject]@{
        OsName = $machineInfo[0].OsName
        BIOSVersion = $machineInfo[0].BiosSMBIOSBIOSVersion
        Model = $machineInfo[0].CsModel
        Name = $machineInfo[0].CsName
        TpmPresent = $machineInfo[1].TpmPresent
        TpmEnabled= $machineInfo[1].TpmEnabled
        TpmVersion = $machineInfo[1].ManufacturerVersion
        AssetTag = $machineInfo[2].SMBIOSAssetTag
        RAID = ($machineInfo[3] -ne $null)
        BitlockerStatus = $machineInfo[4]
        SecureBoot = $machineInfo[5]
    }

     foreach ($result in $machineInfo) {
        $message = $result + '`n'
        Write-Host $message
    }
   
    return $Info_object
}

Check-Online-Status -name $name
$info = Get-Machine-Information -name $name
$object = Build-Information-Object -machineInfo $info