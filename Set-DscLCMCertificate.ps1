function Set-DscLCMCertificate
{
    [CmdletBinding()]
    param (
        [Parameter (Mandatory = $true)]
        [String]
        $ComputerName,
        [Parameter (Mandatory = $false)]
        [String]
        $DSCCertPublicKeyPath = 'C:\DSC\CertPublicKeys'
    )

    Write-Verbose 'Checking DSC cert public key path directory on management machine'
    if((Test-Path $DSCCertPublicKeyPath) -eq $false) 
    {
        Write-Verbose 'Path does not exist. Creating DSC cert public key path directory on target machine.'
        New-Item -ItemType Directory -Path $DSCCertPublicKeyPath | Out-Null
    }
    
    # Generate a self signed certificate on each machine - this is used for encrypting DSC credentials
    $ScriptBlock = {
        param(
            [string]
            $DSCCertPublicKeyPath
        )

        if((Test-Path $DSCCertPublicKeyPath) -eq $false)
        {
            Write-Verbose 'Creating DSC cert public key path directory on target machine'
            New-Item -ItemType Directory -Path $DSCCertPublicKeyPath | Out-Null
        }

        $DSCCert = Get-ChildItem cert:\localmachine\my | Where-Object {$_.Subject -eq "CN=DscEncryptionCert"}
        if (!($DSCCert))
        {
            Write-Verbose 'No certificate found. Creating new self signed certificate for DSC.'
            $DSCCert = New-SelfSignedCertificate -Type DocumentEncryptionCertLegacyCsp -DnsName 'DscEncryptionCert' -HashAlgorithm SHA256
        }

        Write-Verbose 'Exporting new certificate to a file on the target computer'
        $DSCCert[0] | Export-Certificate -FilePath "$DSCCertPublicKeyPath\$env:computername.cer" -Force | Out-Null
    } 

    # Create an empty hash table:
    $ConfigurationData = @{
        AllNodes = @()
    }

    ForEach ($Computer in $ComputerName)
    {
        Write-Verbose 'Opening new remote PowerShell session'
        $Session = New-PSSession -ComputerName $ComputerName
        Invoke-Command -Session $Session -ScriptBlock $ScriptBlock -ArgumentList $DSCCertPublicKeyPath
        Write-Verbose 'Copying DSC certificate to the management computer'
        Copy-Item -FromSession $Session -Path "$DSCCertPublicKeyPath\$ComputerName.cer" -Destination $DSCCertPublicKeyPath -Force
        Write-Verbose 'Closing remote PowerShell session'
        Remove-PSSession $Session -Confirm:$false

        # Get the certificate thumbprint from the .cer file
        Write-Verbose 'Getting the DSC certificate thumbprint'
        $Cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
        $Cert.Import("$DSCCertPublicKeyPath\$Computer.cer")

        # Add information to the hashtable
        Write-Verbose 'Adding data to ConfigurationData hashtable'
        $hashtable = @{
            NodeName = $Computer
            CertificateFile = "$DSCCertPublicKeyPath\$Computer.cer"
            PSDscAllowDomainUser = $true
            Thumbprint = $Cert.Thumbprint
        }

        $ConfigurationData.AllNodes += $hashtable
    }

    # Create MOF/META.MOF files and push the DSC configuration
    # LCM configuration
    [DSCLocalConfigurationManager()]
    configuration LCMConfig
    {
        node $AllNodes.NodeName
        {
            Settings
            {
                CertificateID = $Node.Thumbprint
            }
        }
    }
    
    LCMConfig -OutputPath $env:TEMP\LCMConfig -ConfigurationData $ConfigurationData | Out-Null
    Write-Verbose 'Deploying LCM configuration'
    Set-DscLocalConfigurationManager -ComputerName $ComputerName -Path $env:TEMP\LCMConfig
    return $ConfigurationData
}