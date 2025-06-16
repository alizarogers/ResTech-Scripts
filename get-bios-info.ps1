<# 
    Author: Aliza Rogers :)
    Creation Date: May 2025
    Last Updated: June 16, 2025

    This script gets BIOS information from machines and returns a custom object. 
    If the machine is not online, it will retrn an empty object.

        OsName:          string
        BIOSVersion:     string
        Mode:            string
        Name:            string
        BitlockerStatus: enumerated type (volume status) 
        TpmPresent:      boolean
        TpmEnabled:      boolean
        TpmVersion:      string ("1.2" or "2.0")
        AssetTag:        string
        RAID:            boolean
        SecureBoot:      boolean

        If ran with the '-h' flag, it will display color-coded text, instead of returning the object.


        Notes: 
            - This was written with the assumption that the asset tag should match the last 6 digits of the machine name. Review lines 162-166 if the NIU naming convention changes.
            - This script was written for UEFI, and may not work with legacy BIOS machines.
#>

#Requires -RunAsAdministrator

param 
(
    [Parameter(Mandatory=$true)] $name,
    [switch]$h
)
    
$ErrorActionPreference = "Stop"


function Get-Machine-Information {
    param (
        $name
    )

    # returns a custom object, with the results from each command

    try {
        $results = Invoke-Command -ComputerName $name -ScriptBlock{ `
            # Windows Version, BIOS Version, Model of the Machine
            (Get-ComputerInfo | Select-Object OsName, BiosSMBIOSBIOSVersion, CsModel, CsName), `

            # Bitlocker
            (Get-BitLockerVolume C:| Select-Object -ExpandProperty VolumeStatus), `

            # TPM Information
            (Get-Tpm | Select-Object TpmPresent, TpmEnabled, ManufacturerVersionFull20), `
    
            # Asset Tag
            (Get-WmiObject Win32_SystemEnclosure | Select-Object -ExpandProperty SMBIOSAssetTag), `

            # RAID
            ((Get-WmiObject -Class Win32_SCSIController | Where-Object {$_.DriverName -eq "iaStorAC"}) -ne $null) 
    
            # SecureBoot
            (Confirm-SecureBootUEFI)}
      } catch {
            Write-Host "An error occured while retrieving computer information via Invoke-Command."
            Exit
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
        BitlockerStatus = $machineInfo[1]
        TpmPresent = $machineInfo[2].TpmPresent
        TpmEnabled= $machineInfo[2].TpmEnabled
        TpmVersion = if (-not $machineInfo[2].TpmEnabled) {""}
            elseif ($machineInfo[2].ManufacturerVersionFull20 -match "Not Supported"){ "1.2" } 
            else { "2.0"}
        AssetTag = $machineInfo[3]
        RAID = $machineInfo[4]
        SecureBoot = $machineInfo[5]
    }

    return $Info_object
}

if (!(Test-Connection -ComputerName $name -Count 1 -Quiet)) {
    if ($h) {
        $message = $name + " is not online."
        Write-Host $message
        return
    }
    else {
       return [pscustomobject]@{}
    }
         
}
elseif ($h){ # if machine is online & -h flag
    $message = $name + " is online. Proceeding to check BIOS information. `n"
    Write-Host $message
}

$info = Get-Machine-Information -name $name
$object = Build-Information-Object -machineInfo $info

if ($h)
{
    # I tried to make this as squished together as possible, because it is primarily determining what color the text should be. 
    
    $message = "Name            : " + $object.Name + "`n" + "Model           : " + $object.Model + "`n" + "BIOSVersion     : " + $object.BIOSVersion + "`n"
    Write-Host $message

    # OS Name
    $message = "OsName          : " + $object.OSName + "`n"
    if ($object.OSName -match "11"){ Write-Host $message -ForegroundColor Green } else { Write-Host $message -ForegroundColor Red }

    #Bitlocker Status
    $status = Out-String -InputObject $object.BitlockerStatus.Value
    $message = "BitlockerStatus : " + $status
    if ($message -match "Decrypted") { Write-Host $message -ForegroundColor Red } else { Write-Host $message -ForegroundColor Green }

    # TPM 
    if (!$object.TpmPresent){ Write-Host "TPM             : Not Present `n" -ForegroundColor Red} elseif (!$object.TpmEnabled) { Write-Host "TPM             : Not Present `n" }
    else { # if tpm is present and enabled
        if ($object.TPMVersion -eq "1.2"){ write-Host "TPM             : 1.2 `n" -ForegroundColor Red} 
        else { Write-Host "TPM             : 2.0 `n" -ForegroundColor Green} }


    # Asset Tag
    if ( $object.AssetTag -eq "" ) { Write-Host "Asset Tag       : Not set `n" -ForegroundColor Red } 
    elseif ($object.Name -match $object.AssetTag) { $message = 'Asset Tag       : ' + $object.AssetTag + "`n"
        Write-Host $message -ForegroundColor Green}
    else { $message = "Asset Tag       : " + $object.AssetTag +" (Discrepency. Machine name : " + $object.Name + "`n" 
        Write-Host $message -ForegroundColor Red }

    #RAID
    if ($object.RAID){ Write-Host "RAID            : on `n" -ForegroundColor Red } else { Write-Host "RAID            : off `n" -ForegroundColor Green }

    # Secure Boot
    if ($object.SecureBoot) { Write-Host "Secure Boot     : on `n" -ForegroundColor Green } else { Write-Host "Secure Boot     : off `n" -ForegroundColor Red}
}
else {
    return $object
}