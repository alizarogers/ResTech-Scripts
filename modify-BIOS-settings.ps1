function Confirm-Module { # [untested] Returns whether the operation was successful or not. 
    # This function must be ran with administrator privileges. 
    param ( $moduleName = "DellBIOSProvider" )

    # if the module is not installed, install it
    if (-not $(Get-Module -Name $moduleName -ListAvailable)){ 
        try {
            Install-Module -Name $moduleName
        } catch {
            Write-Error "There was an error while installing $moduleName. (Check admin privileges.)"
            Return $false
        }
    }
    
    try {
        Import-Module DellBIOSProvider -ErrorAction Stop # adding this flag, since try-catch only works on terminating errors
    } catch {
        Write-Error "There was an error while importing $modulename."
        Return $false
    }

    # in case import-module doesn't throw an error, but didn't create the DellSmbios drive
    try {
        ls DellSmbios:/
    } catch {
        Write-Error "There was an issue with accessing the DellSMbios drive."
        Return $false
    }

    Return $true
}

function Set-AssetTag { # [untested] Returns whether the operation was successful or not. 

    param ( [Parameter(Mandatory=$true)] $assetTag )

    if ( -not (Confirm-Module)) {
        Write-Error "An error occured while installing the Dell BIOS Powershell module. (Necessary for enabling secure boot.)"
        Return $false
    }

    try {
        Set-Item DellSmbios:\SystemInformation\Asset $assetTag
    } catch {
        Write-Error "There was an error while trying to set the asset tag."
        Return $false
    }

    Return $true
}

function Enable-SecureBoot { # [untested] Returns whether the operation was successful or not. 

    if ( -not (Confirm-Module)) {
        Write-Error "An error occured while installing the Dell BIOS Powershell module. (Necessary for enabling secure boot.)"
        Return $false
    }

    # confirm that legacy option ROMs option is disabled (necesarry to turn secure boot on)
    Set-Location DellSmbios:\AdvancedBootOptions\
    if ((Get-Item .\LegacyOrom).CurrentValue -eq "Enabled") {
        try {
            Set-Item DellSmbios:\AdvancedBootOptions\LegacyOrom "Disabled"
        } catch {
            Write-Error "An error occured while disabling legacy option ROMs. (Necessary for enabling secure boot.)"
            Return $false
        }  
    }
}

