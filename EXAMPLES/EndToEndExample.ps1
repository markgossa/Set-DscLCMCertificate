# Get credentials
$Credential = Get-Credential litware\administrator

# Configure your node for DSC credential encryption
$ConfigurationData = Set-DscLCMCertificate -ComputerName litex01

# Create a test configuration
configuration TestFile
{
    param(
        [Parameter(Mandatory = $true)]
        [PSCredential]
        $Credential
    )
    
    Import-DscResource -ModuleName PSDesiredStateConfiguration

    node $AllNodes.NodeName
    {
        file TestFile
        {
            SourcePath = '\\litcli01\c$\temp\testfile1.txt'
            DestinationPath = 'C:\temp\testfile1.txt'
            Credential = $Credential 
        }
    }
}

# Create the MOF file
TestFile -Credential $Credential -ConfigurationData $ConfigurationData -OutputPath C:\temp | Out-Null

# Deploy your configuration
Start-DscConfiguration -ComputerName litex01 -Path C:\temp -Verbose -Wait -Force

# Test your configuration
Get-Item '\\litex01\c$\temp\testfile1.txt'