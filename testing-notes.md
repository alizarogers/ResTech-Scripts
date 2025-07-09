# Modify-BIOS-Settings

A restart is **required** for any BIOS changes to take effect.

## Confirm-Module: 

Depending on the module needed, there may be command line confirmations required.

It has been tested in the following cases:
    - The module has not been installed before.
    - The module has been installed, but needs to be imported. 
    - The module does not need to be installed or imported. 


## Enable-SecureBoot

Still needs testing with machines that have a legacy orom option. 

It has been tested in the following cases:
    - Secure boot is off and legacy orom is not an option.
    - Secure boot is on and legacy orom is not an option. 


## Set-AssetTag 

It has been tested in the following cases:
    - There was a previous asset tag that needed to be overwritten.
#>