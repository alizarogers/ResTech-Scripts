function Confirm-Module { # Returns whether the operation was successful or not. 
    # This function must be ran with administrator privileges. 
    param ( $moduleName = "DellBIOSProvider")

    # if the module is not installed, install it
    if (-not $(Get-Module -Name $moduleName -ListAvailable)){ 
        try {
            # NOTE: Modules may require command line confirmation
            Install-Module -Name $moduleName
        } catch {
            Write-Error "There was an error while installing $moduleName. (Check admin privileges.)"
            Return $false
        }
    }
    
    try {
        Import-Module $moduleName -ErrorAction Stop # adding this flag, since try-catch only works on terminating errors
    } catch {
        Write-Error "There was an error while importing $modulename."
        Return $false
    }

    # DellSmbios-specific test
    if ($moduleName -eq "DellBIOSProvider")
    {
        try {
            $catch = Test-Path "DellSmbios:/"
        } catch {
            Write-Error "There was an issue with accessing the DellSMbios drive."
            Return $false
        }
    }

    Return $true
}

function Set-AssetTag { # [untested] Returns whether the operation was successful or not. 

    param ( [Parameter(Mandatory=$true)] $assetTag )

    if ( -not (Confirm-Module)) {
        Write-Error "An error occured while installing the Dell BIOS Powershell module. (Necessary for setting the asset tag.)"
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

function Enable-SecureBoot { # Returns whether the operation was successful or not. 

    if ( -not (Confirm-Module)) {
        Write-Error "An error occured while installing the Dell BIOS Powershell module. (Necessary for enabling secure boot.)"
        Return $false
    }

    # confirm that legacy option ROMs option is disabled (necesarry to turn secure boot on)
    if ((ls DellSmbios:\AdvancedBootOptions\).count -gt 1 -and (Get-Item DellSmbios:\AdvancedBootOptions\LegacyOrom).CurrentValue -eq "Disabled") {
        try {
            Set-Item DellSmbios:\AdvancedBootOptions\LegacyOrom "Disabled"
        } catch {
            Write-Error "An error occured while disabling legacy option ROMs. (Necessary for enabling secure boot.)"
            Return $false
        }  
    }

    if ((Get-Item DellSmbios:\SecureBoot\SecureBoot).CurrentValue -eq "Disabled")
    {
        try {
            Set-Item DellSmbios:\SecureBoot\SecureBoot "Enabled"
        } catch {
            Write-Error "There was an error while trying to enable secure boot."
        }
    }

    Return $true
}

function Switch-toAHCI { # UNTESTED

    if ( -not (Confirm-Module)) {
        Write-Error "An error occured while installing the Dell BIOS Powershell module. (Necessary for switching to AHCI.)"
        Return $false
    }

    if ((Get-Item DellSmbios:\SystemConfiguration\EmbSataRaid).CurrentValue -eq "Raid")
    {
        Set-Item DellSmbios:\SystemConfiguration\EmbStataRaid "Ahci"
    }

    Set-ItemProperty -path "Computer\HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" -Value { 
        bcdedit /deletevalue safeboot
        shutdown \r }

    bcdedit /set safeboot network
    shutdown \r
}

 

