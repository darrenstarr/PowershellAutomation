<#
This code is written and maintained by Darren R. Starr from Nocturnal Holdings AS Norway.

License :

Copyright (c) 2016 Nocturnal Holdings AS Norway

Permission is hereby granted, free of charge, to any person obtaining a 
copy of this software and associated documentation files (the "Software"), 
to deal in the Software without restriction, including without limitation 
the rights to use, copy, modify, merge, publish, distribute, sublicense, 
and/or sell copies of the Software, and to permit persons to whom the Software 
is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in 
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A 
PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT 
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION 
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE 
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#>

<#
    .SYNOPSIS 
        An API for generating Unattend.xml files for Windows Server 2016

    .DESCRIPTION
        UnattendXML is a class designed for generating "properly formatted" XML
        that meets the schema requirements of Microsoft's Windows Server 2016 unattend.xml
        format.

        The code is written as a flat class instead of a serialized data structure as the 
        excessive additional complexity one would expect from serialization would be 
        overwhelming to implement.

        Given the current state of the class, it is only implemented as much as necessary
        to perform the operations the author of the class needed. As comments, needs and 
        suggestions as well as patches increase, the functionality of the class will increase.

        The current design risks a namespace clutter and possibily even constraints due to its
        flat but easy to use nature.

    .EXAMPLE
        using module UnattendXML.psm1

        $unattend = [UnattendXml]::new()
        $unattend.SetComputerName('BobsPC')
        $unattend.SetRegisteredOwner('Bob Minion')
        $unattend.SetRegisteredOrganization('Minions Evil Empire')
        $unattend.SetTimeZone('W. Europe Standard Time')
        $unattend.SetAdministratorPassword('C1sco12345')
        $unattend.SetInterfaceIPAddress('Ethernet', '10.1.1.5', 24, '10.1.1.1')
        $unattend.SetDHCPEnabled('Ethernet', $false)
        $unattend.SetRouterDiscoveryEnabled('Ethernet', $false)
        $unattend.SetInterfaceIPv4Metric('Ethernet', 10)
        $outputXML = $unattend.ToXml()
#>
class UnattendXml 
{
    hidden [Xml]$document = (New-Object -TypeName Xml)
    hidden [System.Xml.XmlElement]$XmlUnattended

    hidden static [string] $XmlNs = 'urn:schemas-microsoft-com:unattend'
    hidden static [string] $ProcessorArchitecture='amd64'
    hidden static [string] $VersionScope='nonSxS'
    hidden static [string] $LanguageNeutral='neutral'
    hidden static [string] $WCM = 'http://schemas.microsoft.com/WMIConfig/2002/State'
    hidden static [string] $XmlSchemaInstance = 'http://www.w3.org/2001/XMLSchema-instance'

    hidden [System.Xml.XmlElement] GetSettingsNode([string]$Pass)
    {
        # TODO : Should this be -eq $Pass?
        $result = $this.XmlUnattended.ChildNodes | Where { $_.Name -eq 'Settings' -and $_.Attributes['pass'].'#text' -like $Pass }
        If ($result -eq $null) {
            $result = $this.document.CreateElement('settings', $this.document.DocumentElement.NamespaceURI)
            $result.SetAttribute('pass', $Pass)
            $this.XmlUnattended.AppendChild($result) | Out-Null
        } 

        return $result
    }

    hidden [System.Xml.XmlElement] GetOfflineServicingSettings()
    {
        return $this.GetSettingsNode('offlineServicing')
    }

    hidden [System.Xml.XmlElement] GetSpecializeSettings()
    {
        return $this.GetSettingsNode('specialize')
    }    

    hidden [System.Xml.XmlElement] GetSectionFromSettings([System.Xml.XmlElement]$XmlSettings, [string]$Name)
    {
        $result = $XmlSettings.ChildNodes | Where { $_.LocalName -eq 'component' -and $_.Attributes['name'].'#text' -eq $Name }
        if ($result -eq $null)
        {
            $result = $this.document.CreateElement('component', $this.document.DocumentElement.NamespaceURI)
            $result.SetAttribute('name', $Name)
            $result.SetAttribute('processorArchitecture', [UnattendXml]::ProcessorArchitecture)
            $result.SetAttribute('publicKeyToken', '31bf3856ad364e35')
            $result.SetAttribute('language', [UnattendXml]::LanguageNeutral)
            $result.SetAttribute('versionScope', [UnattendXml]::VersionScope)
            $result.SetAttribute('xmlns:wcm', [UnattendXml]::WCM)
            $result.SetAttribute('xmlns:xsi', [UnattendXml]::XmlSchemaInstance)

            $XmlSettings.AppendChild($result) | Out-Null
        }

        return $result
    }

    hidden [System.Xml.XmlElement] GetWindowsShellSetupSection([System.Xml.XmlElement]$XmlSettings)
    {
        return $this.GetSectionFromSettings($XmlSettings, 'Microsoft-Windows-Shell-Setup')
    }

    hidden [System.Xml.XmlElement] GetWindowsTCPIPSection([System.Xml.XmlElement]$XmlSettings)
    {
        return $this.GetSectionFromSettings($XmlSettings, 'Microsoft-Windows-TCPIP')
    }

    hidden [System.Xml.XmlElement] GetTCPIPInterfaces([System.Xml.XmlElement]$XmlSettings)
    {
        $XmlComponent = $this.GetWindowsTCPIPSection($XmlSettings)
        $result = $XmlComponent.ChildNodes | Where { $_.Name -eq 'Interfaces' }
        if ($result -eq $null) {
            $result = $this.document.CreateElement('Interfaces', $this.document.DocumentElement.NamespaceURI)
            $XmlComponent.AppendChild($result) | Out-Null
        }
    
        return $result
    }

    hidden [System.Xml.XmlElement] GetTCPIPInterfaceFromInterfaces([System.Xml.XmlElement]$Interfaces, [string]$Identifier)
    {
        $interfaceNodes = $Interfaces.ChildNodes | Where { $_.LocalName -eq 'Interface' }
        foreach($interfaceNode in $interfaceNodes) {
            $identifierNode = $interfaceNode.ChildNodes | Where { $_.LocalName -eq $Identifier }
            if ($identifierNode.InnerText -eq $IdentifierNode) {
                return $interfaceNode
            }
        }   
        
        $interfaceNode = $this.document.CreateElement('Interface', $this.document.DocumentElement.NamespaceURI)
        $interfaceNode.SetAttribute('wcm:action', 'add')
        $Interfaces.AppendChild($interfaceNode)

        $identifierNode = $this.document.CreateElement('Identifier', $this.document.DocumentElement.NamespaceURI)
        $identifierNodeText = $this.document.CreateTextNode($Identifier)
        $identifierNode.AppendChild($identifierNodeText)
        $interfaceNode.AppendChild($identifierNode)

        return $interfaceNode
    }

    hidden [System.Xml.XmlElement] GetTCPIPInterface([System.Xml.XmlElement]$XmlSettings, [string]$Identifier)
    {
        $interfaces =$this.GetTCPIPInterfaces($XmlSettings)
        return $this.GetTCPIPInterfaceFromInterfaces($interfaces, $Identifier)
    }

    hidden [System.Xml.XmlElement] GetOrCreateChildNode([System.Xml.XmlElement]$ParentNode, [string]$LocalName)
    {
        $result = $ParentNode.ChildNodes | Where { $_.LocalName -eq $LocalName }
        if ($result -eq $null) {
            $result = $this.document.CreateElement($LocalName, $this.document.DocumentElement.NamespaceURI)
            $ParentNode.AppendChild($result)
        }

        return $result
    }

    hidden [System.Xml.XmlElement] GetTCPIPv4Settings([System.Xml.XmlElement]$Interface)
    {
        return $this.GetOrCreateChildNode($Interface, 'IPv4Settings')
    }

    hidden [System.Xml.XmlElement] GetTCPIPv4Setting([System.Xml.XmlElement]$Interface, [string]$SettingName)
    {
        $settings = $this.GetTCPIPv4Settings($Interface)
        return $this.GetOrCreateChildNode($settings, $SettingName)
    }

    hidden [System.Xml.XmlElement] GetTCPIPUnicastIPAddresses([System.Xml.XmlElement]$Interface)
    {
        return $this.GetOrCreateChildNode($Interface, 'UnicastIPAddresses')
    }

    hidden [System.Xml.XmlElement] GetTCPIPUnicastIPAddress([System.Xml.XmlElement]$Interface, [string]$KeyValue)
    {
        $unicastIPAddresses = $this.GetTCPIPUnicastIPAddresses($Interface)
        $result = $unicastIPAddresses.ChildNodes | Where { $_.LocalName -eq 'IpAddress' -and $_.Attributes['keyValue'].'#text' -eq $KeyValue }
        if ($result -eq $null) {
            $result = $this.document.CreateElement('IpAddress', $this.document.DocumentElement.NamespaceURI)
            $result.SetAttribute('wcm:action', 'add')
            $result.SetAttribute('wcm:keyValue', $KeyValue)
            $unicastIPAddresses.AppendChild($result)
        }

        return $result
    }

    hidden [System.Xml.XmlElement] GetTCPIPRoutes([System.Xml.XmlElement]$Interface)
    {
        return $this.GetOrCreateChildNode($Interface, 'Routes')
    }

    hidden [System.Xml.XmlElement] GetTCPIPRoute([System.Xml.XmlElement]$Interface, [string]$Prefix)
    {
        $routes = $this.GetTCPIPRoutes($Interface)
        
        $routeNodes = ($routes.ChildNodes | Where { $_.LocalName -eq 'Route' })
        $routeIdentifier = '0'

        # TODO : Better handling of when there's a missing identifier or prefix node
        foreach($routeNode in $routeNodes) {
            $prefixNode = ($routeNode.ChildNodes | Where { $_.LocalName -eq 'Prefix' })
            if ($prefixNode.InnerText -eq $Prefix) {
                return $routeNode
            }

            $identifierNode = $routeNode.ChildNodes | Where { $_.LocalName -eq 'Identifier' }
            
            if(([Convert]::ToInt32($identifierNode.InnerText)) -gt ([Convert]::ToInt32($routeIdentifier))) {
                $routeIdentifier = $identifierNode.InnerText
            }
        }        

        $routeIdentifier = ([Convert]::ToInt32($routeIdentifier)) + 1

        $routeNode = $this.document.CreateElement('Route', $this.document.DocumentElement.NamespaceURI)
        $routeNode.SetAttribute('wcm:action', 'add')
        $routes.AppendChild($routeNode)

        $identifierNode = $this.document.CreateElement('Identifier', $this.document.DocumentElement.NamespaceURI)
        $identifierNodeText = $this.document.CreateTextNode($routeIdentifier.ToString())
        $identifierNode.AppendChild($identifierNodeText)
        $routeNode.AppendChild($identifierNode)

        $prefixNode = $this.document.CreateElement('Prefix', $this.document.DocumentElement.NamespaceURI)
        $prefixNodeText = $this.document.CreateTextNode($Prefix)
        $prefixNode.AppendChild($prefixNodeText)
        $routeNode.AppendChild($prefixNode)

        return $routeNode
    }

    hidden [string]ConvertToString([SecureString]$SecureString)
    {
        if (-not $SecureString)
        {
            return $null
        }

        $ManagedPasswordString = $null
        $PointerToPasswordString = $null
        try
        {
            $PointerToPasswordString = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($SecureString)
            $ManagedPasswordString = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($PointerToPasswordString)
        }
        finally
        {
            [System.Runtime.InteropServices.Marshal]::ZeroFreeCoTaskMemUnicode($PointerToPasswordString)
        }
    
        return $ManagedPasswordString
    }

    hidden [void]SetAdministratorPassword([SecureString]$AdministratorPassword)
    {
        $xmlSettings = $this.GetOfflineServicingSettings()
        $XmlComponent = $this.GetWindowsShellSetupSection($xmlSettings)

        $XmlUserAccounts = $this.document.CreateElement('OfflineUserAccounts', $this.document.DocumentElement.NamespaceURI)
        $XmlComponent.AppendChild($XmlUserAccounts)

        $XmlAdministratorPassword = $this.document.CreateElement('OfflineAdministratorPassword', $this.document.DocumentElement.NamespaceURI)
        $XmlUserAccounts.AppendChild($XmlAdministratorPassword) 

        $XmlValue = $this.document.CreateElement('Value', $this.document.DocumentElement.NamespaceURI)
        $XmlText = $this.document.CreateTextNode([Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes(($this.ConvertToString($AdministratorPassword)) + 'OfflineAdministratorPassword')))
        $XmlValue.AppendChild($XmlText)
        $XmlAdministratorPassword.AppendChild($XmlValue)

        $XmlPlainText = $this.document.CreateElement('PlainText', $this.document.DocumentElement.NamespaceURI)
        $XmlPassword = $this.document.CreateTextNode('false')
        $XmlPlainText.AppendChild($XmlPassword)
        $XmlAdministratorPassword.AppendChild($XmlPlainText) 
    }

    hidden [void]SetTextNodeValue([System.Xml.XmlElement]$Parent, [string]$NodeName, [string]$Value)
    {
        $namedNode = $this.GetOrCreateChildNode($Parent, $NodeName)
        $textValueNode = $this.document.CreateTextNode($Value)
        $namedNode.AppendChild($textValueNode) 
    }

    hidden [void]SetBoolNodeValue([System.Xml.XmlElement]$Parent, [string]$NodeName, [bool]$Value)
    {
        $this.SetTextNodeValue($Parent, $NodeName, ($Value.ToString().ToLower()))
    }

    hidden [void]SetInt32NodeValue([System.Xml.XmlElement]$Parent, [string]$NodeName, [Int32]$Value)
    {
        $this.SetTextNodeValue($Parent, $NodeName, ($Value.ToString()))
    }

    UnattendXml() 
    {
        $XmlDecl = $this.document.CreateXmlDeclaration('1.0', 'utf-8', $Null)
        $XmlRoot = $this.document.DocumentElement
        $this.document.InsertBefore($XmlDecl, $XmlRoot)

        $this.XmlUnattended = $this.document.CreateElement('unattend', [UnattendXml]::XmlNs)
        $this.XmlUnattended.SetAttribute('xmlns:wcm', [UnattendXML]::WCM)
        $this.XmlUnattended.SetAttribute('xmlns:xsi', [UnattendXML]::XmlSchemaInstance)
        $this.document.AppendChild($this.XmlUnattended) 
    }

    <#
        .SYNOPSIS
            Configures the registered owner of the Windows installation
    #>
    [void]SetRegisteredOwner([string]$RegisteredOwner)
    {
        $offlineServiceSettings = $this.GetOfflineServicingSettings()
        $windowsShellSetupNode = $this.GetWindowsShellSetupSection($offlineServiceSettings)
        $this.SetTextNodeValue($windowsShellSetupNode, 'RegisteredOwner', $RegisteredOwner)
    }

    <#
        .SYNOPSIS
            Configures the registered organization of the Windows installation
    #>
    [void]SetRegisteredOrganization([string]$RegisteredOrganization)
    {
        $offlineServiceSettings = $this.GetOfflineServicingSettings()
        $windowsShellSetupNode = $this.GetWindowsShellSetupSection($offlineServiceSettings)
        $this.SetTextNodeValue($windowsShellSetupNode, 'RegisteredOrganization', $RegisteredOrganization)        
    }

    <#
        .SYNOPSIS
            Configures the name of the computer
    #>
    [void]SetComputerName([string]$ComputerName)
    {
        $offlineServiceSettings = $this.GetOfflineServicingSettings()
        $windowsShellSetupNode = $this.GetWindowsShellSetupSection($offlineServiceSettings)
        $this.SetTextNodeValue($windowsShellSetupNode, 'ComputerName', $ComputerName)        
    }

    <#
        .SYNOPSIS
            Configures the time zone for the computer
        .NOTES
            The configured time zone must be a valid value as defined by Microsoft
        .LINK
            https://technet.microsoft.com/en-us/library/cc749073(v=ws.10).aspx
    #>
    [void]SetTimeZone([string]$TimeZone)
    {
        $offlineServiceSettings = $this.GetOfflineServicingSettings()
        $windowsShellSetupNode = $this.GetWindowsShellSetupSection($offlineServiceSettings)
        $this.SetTextNodeValue($windowsShellSetupNode, 'TimeZone', $TimeZone)                
    }

    <#
        .SYNOPSIS
            Sets the state of whether DHCPv4 is enabled for a given interface
        .LINK
            https://technet.microsoft.com/en-us/library/cc748924(v=ws.10).aspx
    #>
    [void]SetDHCPEnabled([string]$InterfaceIdentifier, [bool]$Enabled)
    {
        $XmlSettings = $this.GetSpecializeSettings()
        $interfaceNode = $this.GetTCPIPInterface($XmlSettings, $InterfaceIdentifier)
        $interfaceTCPIPSettings = $this.GetTCPIPv4Settings($interfaceNode)
        $this.SetBoolNodeValue($interfaceTCPIPSettings, 'DhcpEnabled', $Enabled)
    }

    <#
        .SYNOPSIS
            Sets the state of whether IPv4 Router Discovery is enabled for a given interface
        .LINK
            https://technet.microsoft.com/en-us/library/cc749578(v=ws.10).aspx
            https://www.ietf.org/rfc/rfc1256.txt
            https://en.wikipedia.org/wiki/ICMP_Router_Discovery_Protocol
    #>
    [void]SetRouterDiscoveryEnabled([string]$InterfaceIdentifier, [bool]$Enabled)
    {
        $XmlSettings = $this.GetSpecializeSettings()
        $interfaceNode = $this.GetTCPIPInterface($XmlSettings, $InterfaceIdentifier)
        $interfaceTCPIPSettings = $this.GetTCPIPv4Settings($interfaceNode)
        $this.SetBoolNodeValue($interfaceTCPIPSettings, 'RouterDiscoveryEnabled', $Enabled)
    }

    <#
        .SYNOPSIS
            Sets the IPv4 routing metric value for the interface itself.
        .NOTES
            If you don't understand this value, set it to 10. 
        .LINK
            https://technet.microsoft.com/en-us/library/cc766415(v=ws.10).aspx
    #>
    [void]SetInterfaceIPv4Metric([string]$InterfaceIdentifier, [Int32]$Metric)
    {
        $XmlSettings = $this.GetSpecializeSettings()
        $interfaceNode = $this.GetTCPIPInterface($XmlSettings, $InterfaceIdentifier)
        $interfaceTCPIPSettings = $this.GetTCPIPv4Settings($interfaceNode)
        $this.SetInt32NodeValue($interfaceTCPIPSettings, 'Metric', $Metric)
    }

    <#
        .SYNOPSIS
            Sets the IPv4 address, subnet mask, ad default gateway for the given interface.
        .NOTES
            While multiple addresses are allowed on an interface, this function 
            assumes you'll have only one.

            It is recommended that when configuring a static IP address, you :
              * Disable DHCPv4 for the interface
              * Disable IPv4 ICMP Router Discovery for the interface
              * Configure a proper routing metric for the interface
        .LINK
            https://technet.microsoft.com/en-us/library/cc749412(v=ws.10).aspx
            https://technet.microsoft.com/en-us/library/cc749535(v=ws.10).aspx
    #>
    [void]SetInterfaceIPAddress([string]$InterfaceIdentifier, [string]$IPAddress, [Int32]$PrefixLength, [string]$DefaultGateway)
    {
        $XmlSettings = $this.GetSpecializeSettings()
        $interfaceNode = $this.GetTCPIPInterface($XmlSettings, $InterfaceIdentifier)
        $ipAddressNode = $this.GetTCPIPUnicastIPAddress($interfaceNode, '1')

        # TODO : Handle pre-existing inner text node.
        $ipAddressTextNode = $this.document.CreateTextNode(("{0}/{1}" -f $IPAddress,$PrefixLength))
        $ipAddressNode.AppendChild($ipAddressTextNode)

        # TODO : Create 'SetRoute' member function which modifies the value if it's already set
        $routeNode = $this.GetTCPIPRoute($interfaceNode, '0.0.0.0/0')
        
        $metricNode = $this.document.CreateElement('Metric', $this.document.DocumentElement.NamespaceURI)
        $metricNodeText = $this.document.CreateTextNode('10')
        $metricNode.AppendChild($metricNodeText)
        $routeNode.AppendChild($metricNode)

        $nextHopNode = $this.document.CreateElement('NextHopAddress', $this.document.DocumentElement.NamespaceURI)
        $nextHopNodeText = $this.document.CreateTextNode($DefaultGateway)
        $nextHopNode.AppendChild($nextHopNodeText)
        $routeNode.AppendChild($nextHopNode)
    }    

    <#
        .SYNOPSIS
            Configures the administrator password for the new System
        .NOTES
            This command uses a plain text password.
        .LINK
            https://msdn.microsoft.com/en-us/library/windows/hardware/dn986490(v=vs.85).aspx
    #>
    [void] SetAdministratorPassword([string]$AdministratorPassword) {
        $this.SetAdministratorPassword((ConvertTo-SecureString $AdministratorPassword -AsPlainText -Force))
    }

    <#
        .SYNOPSIS
            Generates XML text that can be saved to a file 
    #>
    [string]ToXml()
    {
        $xmlWriterSettings = New-Object System.Xml.XmlWriterSettings
        $xmlWriterSettings.Indent = $true;
        $xmlWriterSettings.Encoding = [System.Text.Encoding]::Utf8

        $stringWriter = New-Object System.IO.StringWriter
        $xmlWriter = [System.Xml.XmlWriter]::Create($stringWriter, $xmlWriterSettings)

        $this.document.WriteContentTo($xmlWriter)

        $xmlWriter.Flush()
        $stringWriter.Flush()

        return $stringWriter.ToString() 
    }
}
