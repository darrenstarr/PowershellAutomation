<#PSScriptInfo 
    .VERSION 1.0.0 
    .GUID 1abcbef0-1c9d-4aad-a00a-d4b17040b3f5 
    .AUTHOR Darren R. Starr 
    .COMPANYNAME Conscia Norway AS 
    .COPYRIGHT 2016 Conscia Norway AS 
    .TAGS netsh 
    .LICENSEURI https://opensource.org/licenses/MIT 
    .PROJECTURI https://github.com/darrenstarr/PowershellAutomation 
    .ICONURI 
    .EXTERNALMODULEDEPENDENCIES 
    .REQUIREDSCRIPTS 
    .EXTERNALSCRIPTDEPENDENCIES 
    .RELEASENOTES 
        1.0.0
          - Initial release of a NetShell class
#>

<# 
    .DESCRIPTION 
        Powershell classes to process output of NetShell as powershell objects
#>
Param()

<#
    .SYNOPSIS
        Base class for refering to NetShell binding representations
#>
class NetShellBindingDefinition
{
    <#
        .SYNOPSIS
            The port bound to
    #>
    [int] $Port
}

<#
    .SYNOPSIS
        Representation of the Central Certificate Store binding 

    .DESCRIPTION
        This class represents the central certificate store binding
        as displayed on the output of netsh http show sslcert. This class
        is not intended to be used directly, but instead is meant to be
        called by parsing functions in the NetShell class
#>
class NetShellBindingCentralCertificateStore : NetShellBindingDefinition
{
    <#
        .SYNOPSIS
            Parses and returns a Central Certificate Store binding object
    #>
    static [NetShellBindingCentralCertificateStore] Parse([string]$input)
    {
        [System.Text.RegularExpressions.MatchCollection] $matches = [RegEx]::Matches($input, '[0-9]+')

        if(
            ($null -eq $matches) -or 
            ($matches.Count -ne 1) -or
            ($matches[0].Success -ne $true) -or
            ($matches[0].Groups.Count -ne 1)
          ) {
            throw 'Invalid input passed to Central Certificate Store binding parser'
        }

        return [NetShellBindingCentralCertificateStore] @{
            Port = [Convert]::ToInt32($matches[0].Groups[0].Value)
        }
    }

    <#
        .SYNOPSIS
            Returns a string representation of the object
    #>
    [string] ToString()
    {
        return ('Central Certificate Store Port :' + $this.Port.ToString())
    }
}

<#
    .SYNOPSIS
        Representation of an IP Address and Port binding

    .DESCRIPTION
        This class represents a IP address and port binding
        as displayed on the output of netsh http show sslcert. This class
        is not intended to be used directly, but instead is meant to be
        called by parsing functions in the NetShell class
#>
class NetShellBindingIPAddressPort : NetShellBindingDefinition
{
    <#
        .SYNOPSIS
            The IP address of the binding
    #>
    [System.Net.IPAddress] $IPAddress

    <#
        .SYNOPSIS
            Parses and returns a IP Address and port binding object
    #>
    static [NetShellBindingIPAddressPort] Parse([string]$input)
    {
        # TODO : Make a better regular expression for matching IP Address
        [System.Text.RegularExpressions.MatchCollection] $matches = [RegEx]::Matches($input, '([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\:([0-9]+)')

        if(
            ($null -eq $matches) -or 
            ($matches.Count -ne 1) -or
            ($matches[0].Success -ne $true) -or
            ($matches[0].Groups.Count -ne 3)
          ) {
            throw 'Invalid input passed to IP:Port binding parser'
        }

        return [NetShellBindingIPAddressPort] @{
            IPAddress = [System.Net.IPAddress]::Parse($matches[0].Groups[1].Value)
            Port = [Convert]::ToInt32($matches[0].Groups[2].Value)
        }
    }

    <#
        .SYNOPSIS
            Returns a string representation of the object
    #>
    [string] ToString()
    {
        return ($this.IPAddress.ToString() + ':' + $this.Port.ToString())
    }
}

<#
    .SYNOPSIS
        Representation of a Hostname and Port binding

    .DESCRIPTION
        This class represents a Hostname and port binding
        as displayed on the output of netsh http show sslcert. This class
        is not intended to be used directly, but instead is meant to be
        called by parsing functions in the NetShell class
#>
class NetShellBindingHostnamePort : NetShellBindingDefinition
{
    <#
        .SYNOPSIS
            The Hostname of the binding
    #>
    [string] $Hostname

    <#
        .SYNOPSIS
            Parses and returns a Hostname and port binding object
    #>
    static [NetShellBindingHostnamePort] Parse([string]$input)
    {
        # TODO : Make a better regular expression for matching hostname
        [System.Text.RegularExpressions.MatchCollection] $matches = [RegEx]::Matches($input, '([^:]+)\:([0-9]+)')

        if(
            ($null -eq $matches) -or 
            ($matches.Count -ne 1) -or
            ($matches[0].Success -ne $true) -or
            ($matches[0].Groups.Count -ne 3)
          ) {
            throw 'Invalid input passed to Hostname:Port binding parser'
        }

        return [NetShellBindingHostnamePort] @{
            IPAddress = [System.Net.IPAddress]::Parse($matches[0].Groups[1].Value)
            Hostname = $matches[0].Groups[2].Value
        }
    }

    <#
        .SYNOPSIS
            Returns a string representation of the object
    #>
    [string] ToString()
    {
        return ($this.Hostname + ':' + $this.Port.ToString())
    }
}

<#
    .SYNOPSIS
        Representation of record from the output of netsh show sslcert
#>
class NetshellSSLBinding
{
    [NetshellBindingDefinition]$PortBinding = $null
    [string]$CertificateHash
    [GUID]$ApplicationID
    [string]$CertificateStoreName
    [bool]$VerifyClientCertificateRevocation
    [bool]$VerifyRevocationUsingCachedClientCertificateOnly
    [bool]$UsageCheck
    [TimeSpan]$RevocationFreshnessTime
    [TimeSpan]$UrlRetrievalTimeout
    [string[]]$CtlIdentifier
    [string]$CtlStoreName
    [bool]$DsMapperUsage
    [bool]$NegotiateClientCertificate
    [bool]$RejectConnections
}

<#
    .SYNOPSIS
        A class wrapper around netsh from Windows

    .DESCRIPTION
        This class implements functions as static members to execute
        and structure the output from netsh from within Windows.
        
        The progress of development of this class is directly in relation
        to the necessity of adding functionality where it is not readily
        available elsewhere in standard Powershell scripts.

        This class was written initially because WebManagement and xWebManagement
        modules from the OneGet repository lacked any method of finding
        the thumbprint of an SSL binding not directly connected to and IIS
        website. This made construction of a DSC resource to bind to 
        configure a certificate for the Web Management Service of IIS 
        impossible.
#>
class NetShell
{
    <#
        .SYNOPSIS
            Returns a the full path of the netsh.exe found in the path
    #>
    hidden static [string] NetshPath() {
        return (Get-Command -Name 'netsh.exe').Source
    }

    <#
        .SYNOPSIS
            Returns a GUID or null given a string input
    #>
    hidden static [Guid] ParseGuid([string]$input)
    {
        if(($null -eq $input) -or ($input -eq '(null)')) {
            return $null
        }
        return [Guid]::Parse($input)
    }

    <#
        .SYNOPSIS
            Returns a string value or null given a string input
    #>
    hidden static [string] ParseString([string]$input)
    {
        if(($null -eq $input) -or ($input -eq '(null)')) {
            return $null
        }
        return $input
    }

    <#
        .SYNOPSIS
            Returns a string list or null given a string input

        .NOTES
            As I don't have example data to test against (even
            after a few creative google searches, this function
            is incomplete.
    #>
    hidden static [string[]] ParseStringList([string]$input)
    {
        if(($null -eq $input) -or ($input -eq '(null)')) {
            return $null
        }

        # TODO : Find an example of multiple CTL Identifiers to learn to parse it properly

        return @($input)
    }

    <#
        .SYNOPSIS
            Returns a enabled/disabled boolean or null given a string input
    #>
    hidden static [bool] ParseEnabled([string]$input)
    {
        if(($null -eq $input) -or ($input -eq '(null)')) {
            return $null
        }

        switch ($input)
        {
            'Enabled' { return $true }
            'Disabled' { return $false }
            default { throw 'Invalid value for enabled/disabled field' }
        }

        throw "Powershell ISE shouldn't generate warning for this"
    }

    <#
        .SYNOPSIS
            Returns a timespan or null given a seconds count as a string input
    #>
    hidden static [TimeSpan] ParseSeconds([string]$input)
    {
        if(($null -eq $input) -or ($input -eq '(null)')) {
            return $null
        }

        $value = [Convert]::ToInt32($input)

        return [TimeSpan]::FromSeconds($value)
    }

    <#
        .SYNOPSIS
            Returns a timespan or null given a milliseconds count as a string input
    #>
    hidden static [TimeSpan] ParseMilliseconds([string]$input)
    {
        if(($null -eq $input) -or ($input -eq '(null)')) {
            return $null
        }

        $value = [Convert]::ToInt32($input)

        return [TimeSpan]::FromMilliseconds($value)
    }

    <#
        .SYNOPSIS
            Parses the values from a single netsh http show sslcert entry

        .NOTES
            The input of this function is extracted from the netsh http show sslcert
            command. Each line is expected to be formated as 'name ; value' instead of
            a dumb key/value store, this function parses and where convenient verifies
            the content of each field syntactically where the acceptable values are known.
    #>
    hidden static [NetshellSSLBinding] ParseShowSSLCertBlock([string]$input)
    {
        [string[]] $lines = [regex]::Split($input, '\r?\n')

        [NetshellSSLBinding]$result = [NetshellSSLBinding]::new()

        foreach($line in $lines) {
            [string[]] $parts = [regex]::Split($line, '[ \t]+\:[ \t]+')
            if ($parts.Count -ne 2) {
                Write-Warning ('Encountered line with more or less than 3 parts`n' + $line)
            }

            [string]$Name = $parts[0].Trim()
            [string]$Value = $parts[1].Trim() 
            # Write-Debug ('Name = [' + $Name + '], Value = [' + $Value + ']')

            switch($Name)
            {
                'IP:Port' { 
                    $result.PortBinding = [NetShellBindingIPAddressPort]::Parse($Value) 
                }

                'Hostname:Port' {
                    $result.PortBinding = [NetShellBindingHostnamePort]::Parse($Value)
                }

                'Central Certificate Store' { 
                    $result.PortBinding = [NetShellBindingCentralCertificateStore]::Parse($Value) 
                }
                
                'Certificate Hash' { 
                    $result.CertificateHash = [NetShell]::ParseString($Value) 
                }

                'Application ID' {
                    $result.ApplicationID = [NetShell]::ParseGUID($Value) 
                }

                'Certificate Store Name' { 
                    $result.CertificateStoreName = [NetShell]::ParseString($Value) 
                }

                'Verify Client Certificate Revocation' {
                    $result.VerifyClientCertificateRevocation = [NetShell]::ParseEnabled($Value) 
                }

                'Verify Revocation Using Cached Client Certificate Only' { 
                    $result.VerifyRevocationUsingCachedClientCertificateOnly = [NetShell]::ParseEnabled($Value) 
                }

                'Usage Check' {
                    $result.UsageCheck = [NetShell]::ParseEnabled($Value)
                }

                'Revocation Freshness Time' {
                    $result.RevocationFreshnessTime = [NetShell]::ParseSeconds($Value)
                }

                'URL Retrieval Timeout' {
                    $result.UrlRetrievalTimeout = [NetShell]::ParseMilliseconds($Value)
                }

                'Ctl Identifier' {
                    $result.CtlIdentifier = [NetShell]::ParseStringList($Value)
                }

                'Ctl Store Name' {
                    $result.CertificateStoreName = [NetShell]::ParseString($Value)
                }

                'DS Mapper Usage' {
                    $result.DsMapperUsage = [NetShell]::ParseEnabled($Value)
                }

                'Negotiate Client Certificate' {
                    $result.NegotiateClientCertificate = [NetShell]::ParseEnabled($Value)
                }

                'Reject Connections' {
                    $result.RejectConnections = [NetShell]::ParseEnabled($Value)
                }

                default {
                    throw [System.ArgumentException]::new('Unhandled parameter passed to ParseShowSSLCert : ' + $Name, '$input')
                }
            }
        }

        if($null -eq $result.PortBinding) {
            return $null
        }

        return $result
    }

    <#
        .SYNOPSIS
            Parses the full output of 'netsh http show sslcert' on Windows
    #>
    hidden static [NetshellSSLBinding[]] ParseShowSSLCert([string]$input)
    {
        [string[]]$blocks = [regex]::Split($input, '(\r?\n)(\r?\n)+') | Where-Object { $_.trim() -ne '' }

        # TODO : Find out how to make a proper array or list with typecasting here.
        $parseResult = [System.Collections.ArrayList]::new()

        foreach ($block in $blocks)
        {
            if ($block -match 'SSL Certificate bindings:') {
                continue
            }

            [NetshellSSLBinding]$binding = [NetShell]::ParseShowSSLCertBlock($block)
            if ($null -eq $binding) {
                throw [System.ArgumentException]::new('Unable to parse output from netsh http show sslcert', '$input')
            } else {
                $parseResult.Add($binding)
            }
        }

        return $parseResult
    }

    <#
        .SYNOPSIS
            Runs a program and receives the output of stdout or generates a 'meaningful exception'
    #>
    hidden static [string] ExecuteCommand([string]$path, [string[]]$arguments)
    {
        [string]$stdout = ''
        [string]$stderr = ''

        try {
            $processInfo = New-Object System.Diagnostics.ProcessStartInfo
            $processInfo.FileName = $path
            $processInfo.RedirectStandardError = $true
            $processInfo.RedirectStandardOutput = $true
            $processInfo.UseShellExecute = $false
            $processInfo.Arguments = $arguments

            $process = New-Object System.Diagnostics.Process
            $process.StartInfo = $processInfo
            $process.Start()
            $stdout = $process.StandardOutput.ReadToEnd()
            $stderr = $process.StandardError.ReadToEnd()
            $process.WaitForExit()
        } catch {
            throw [System.Exception]::new(('Failed to execute [' + $path + ']`n' + $stderr), $_.Exception)
        }

        return $stdout
    }

    <#
        .SYNOPSIS
            Executes 'netsh http show sslcert' and parses the output as an object
    #>
    static [NetshellSSLBinding[]] ShowSSLCert()
    {
        $commandResult = [NetShell]::ExecuteCommand(([NetShell]::NetshPath()), @('http','show','sslcert'))

        return [NetShell]::ParseShowSSLCert($commandResult)
    }
}

<#
$DebugPreference = "Continue"
$VerbosePreference = "Continue"
[NetShell]::ShowSSLCert()
#>
