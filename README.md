# Set-DscLCMCertificate
For Server 2016 only - connects to the remote machine and generates a new self signed certificate for DSC credential encryption. It then configures the LCM on the target computers and outputs the ConfigurationData hashfile for use by other configurations.

# Examples
Set-DscLCMCertificate -ComputerName litex01 -Verbose

