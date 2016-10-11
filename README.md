# PowershellAutomation
Powershell scripts specifically designed to automate data centers

Powershell Automation is a series of Powershell 5 classes being developed to automate the installation of Windows. While this type of code has been coded several hundred times, my goal is to make a series of highly reusable classes that can be easily extended and debugged as well as integrated in other scripts and projects.

Currently, there are a few classes :
 - BCDBoot : For executing BCDBoot.exe for writing UEFI system partitions for booting Windows.
 - RegistryHive : For mounting an offline registry hive and changing settings
 - UnattendXml : A class for writing properly formed unattend.xml files
 - WindowsVhd : A class for mounting a UEFI bootable Windows installation, installing Windows from an ISO, installing drivers, etc...
 
This is currently work in progress and there's a long way to go. Soon it will be on par with Convert-WindowsImage.ps1 for creating virtual machines for Hyper-V. 

This code is focused entirely on Windows Server 2016 from my perspective. I don't intend to implement much support for MBR partitions and while the code should theoretically work on Windows Server 2012 R2, I will not be testing against it personally.

I am however excited to accept feature requests, patches and most importantly, unit tests.

See also:
https://gallery.technet.microsoft.com/scriptcenter/Convert-WindowsImageps1-0fe23a8f
