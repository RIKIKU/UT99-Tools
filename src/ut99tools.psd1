@{
    # If authoring a script module, the RootModule is the name of your .psm1 file
    RootModule           = 'Ut99Tools.psm1'

    Author               = 'Kyle Smith'

    CompanyName          = ''

    ModuleVersion        = '0.1.1'

    # Use the New-Guid command to generate a GUID, and copy/paste into the next line
    GUID                 = '21d63488-5157-47f1-b3aa-d692f7e61078'

    Copyright            = ''

    Description          = 'For troubleshooting UT 99 servers.'

    # Minimum PowerShell version supported by this module (optional, recommended)
    PowerShellVersion    = '5.1'

    # Which PowerShell Editions does this module work with? (Core, Desktop)
    CompatiblePSEditions = @('Desktop', 'Core')

    # Which PowerShell functions are exported from your module? (eg. Get-CoolObject)
    FunctionsToExport    = @('Find-UtLanServers', 'Get-UtMasterServerEndpointList', 'Invoke-UtServerQuery')
    
    # Which PowerShell aliases are exported from your module? (eg. gco)
    AliasesToExport      = @('')

    # Which PowerShell variables are exported from your module? (eg. Fruits, Vegetables)
    VariablesToExport    = @('')

    # PowerShell Gallery: Define your module's metadata
    PrivateData          = @{
        PSData = @{
            # What keywords represent your PowerShell module? (eg. cloud, tools, framework, vendor)
            Tags         = @('tools' )

            # What software license is your code being released under? (see https://opensource.org/licenses)
            LicenseUri   = 'https://github.com/RIKIKU/UT99-Tools/blob/main/LICENSE'

            # What is the URL to your project's website?
            ProjectUri   = 'https://github.com/RIKIKU/UT99-Tools'

            # What is the URI to a custom icon file for your project? (optional)
            IconUri      = ''

            # What new features, bug fixes, or deprecated features, are part of this release?
            ReleaseNotes = @'
            Initial Release
'@
        }
    }

    # If your module supports updateable help, what is the URI to the help archive? (optional)
    # HelpInfoURI = ''
}