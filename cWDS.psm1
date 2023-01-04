enum Ensure {
    Present
    Absent
}

[DscResource()]  class cWDSInitialize {
    ##  MyFolder is the name of the resource
    [DscProperty(Mandatory)]
    [Ensure]$Ensure

    [DscProperty(Key)]
    [String]$RootFolder

    ## What to do if it's  not in the right state. This returns nothing, indicated by [void].

    [void] Set() {
        if ($this.Ensure -eq [Ensure]::Present) {
            & wdsutil.exe /initialize-server /reminst:"$($this.RootFolder)" /standalone
            & WDSUTIL.exe /Set-Server /Transport /EnableTftpVariableWindowExtension:No
        }
        elseif ($this.Ensure -eq [Ensure]::Absent) {
            & wdsutil /uninitialize-server
        }
    }

    ## Test to ensure  it's in the right state. This returns a Boolean value, indicated by [bool].

    [bool] Test() {
        #
        $regvalue = Get-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\WDSServer\Providers\WDSTFTP -Name "RootFolder" -ErrorAction SilentlyContinue
        $rootfolderset = $regvalue.RootFolder -eq $this.RootFolder
        if ($this.Ensure -eq [Ensure]::Present) {
            return $rootfolderset
        }
        else {
            return -not  $rootfolderset
        }
    }

    ## Get the state.  This returns an instance of the class itself, indicated by [MyFolder]

    [cWDSInitialize] Get() {
        #
        $regvalue = Get-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\WDSServer\Providers\WDSTFTP -Name "RootFolder" -ErrorAction SilentlyContinue
        if ( $null -ne $regvalue.RootFolder ) {
            $this.Ensure = [Ensure]::Present
        }
        else {
            $this.Ensure = [Ensure]::Absent
        }
        return $this
    }
}

[DscResource()]  class cWDSInstallImage {
    ##  MyFolder is the name of the resource
    [DscProperty(Mandatory)]
    [Ensure]$Ensure

    [DscProperty(Key)]
    [String]$ImageName

    [DscProperty()]
    [String]$GroupName

    [DscProperty()]
    [String]$Path

    [DscProperty()]
    [String]$Unattendfile

    [DscProperty()]
    [String]$SrcUnattendfile
    ## What to do if it's  not in the right state. This returns nothing, indicated by [void].

    [void] Set() {
        if ($this.Ensure -eq [Ensure]::Present) {
            if ( $null -eq $this.GroupName ) {
                Write-Verbose "Boot image, importing"
                Import-WdsBootImage -Path $this.Path    
            }
            elseif ( -not (Get-WdsInstallImageGroup -Name $this.GroupName -ErrorAction SilentlyContinue  ) ) {
                Write-Verbose "Creating ImageGroup"
                New-WdsInstallImageGroup -Name $this.groupname
                Write-Verbose "Install image, importing"
                Import-WdsInstallImage -Path $this.Path -ImageName $this.ImageName -ImageGroup $this.GroupName
            }
            else {
                Write-Verbose "Using existing GroupName"
                Write-Verbose "Install image, importing"
                Import-WdsInstallImage -Path $this.Path -ImageName $this.ImageName -ImageGroup $this.GroupName
            }
            if ( $null -ne $this.Unattendfile -and $null -ne $this.GroupName ) {
                [xml]$xml = Get-Content $this.SrcUnattendfile
                $winpe = $xml.unattend.settings | Where-Object { $_.pass -eq 'windowsPE' }
                $winpe.component.Where( { $_.name -eq 'Microsoft-Windows-Setup' } ).WindowsDeploymentServices.ImageSelection.InstallImage.ImageName = $this.ImageName
                $winpe.component.Where( { $_.name -eq 'Microsoft-Windows-Setup' } ).WindowsDeploymentServices.ImageSelection.InstallImage.ImageGroup = $this.GroupName
                $xml.Save( "C:\remoteinstall\WdsClientUnattend\$($this.Unattendfile)" )
            }

        }
        elseif ($this.Ensure -eq [Ensure]::Absent) {
            if ( $null -eq $this.GroupName ) {
                Write-Verbose "Removing BootImage"
                Remove-WdsBootImage -ImageName $this.ImageName
            }
            else {
                Write-Verbose "Removing InstallImage"
                Remove-WdsInstallImage -ImageName $this.ImageName
            }
        }
    }

    ## Test to ensure  it's in the right state. This returns a Boolean value, indicated by [bool].

    [bool] Test() {
        #
        if ( $null -eq $this.GroupName ) {
            Write-Verbose "Test BootImage"
            $image = Get-WdsBootImage -ImageName $this.ImageName -ErrorAction SilentlyContinue
        }
        else {
            Write-Verbose "Test InstallImage"
            $image = Get-WdsInstallImage -ImageName $this.ImageName -ErrorAction SilentlyContinue
        }

        if ($this.Ensure -eq [Ensure]::Present) {
            return $null -ne $image
        }
        else {
            return $false
        }
    }

    ## Get the state.  This returns an instance of the class itself, indicated by [MyFolder]

    [cWDSInstallImage] Get() {
        #
        if ( $null -eq $this.GroupName ) {
            Write-Verbose "Get BootImage"
            $image = Get-WdsBootImage -ImageName $this.ImageName -ErrorAction SilentlyContinue
        }
        else {
            Write-Verbose "Get InstallImage"
            $image = Get-WdsInstallImage -ImageName $this.ImageName -ErrorAction SilentlyContinue
        }

        if ( $null -ne $image.Name ) {
            $this.Ensure = [Ensure]::Present
        }
        else {
            $this.Ensure = [Ensure]::Absent
        }
        return $this
    }
}

[DscResource()]  class cWDSServerAnswer {
    ##  MyFolder is the name of the resource
    [DscProperty(Mandatory)]
    [Ensure]$Ensure

    [DscProperty(Key)]
    [String]$Answer

    ## What to do if it's  not in the right state. This returns nothing, indicated by [void].

    [void] Set() {
        if ($this.Ensure -eq [Ensure]::Present) {
            & wdsutil.exe /set-server /AnswerClients:"$($this.Answer)"
        }
        elseif ($this.Ensure -eq [Ensure]::Absent) {
            & wdsutil /set-server /AnswerClients:none
        }
    }

    ## Test to ensure  it's in the right state. This returns a Boolean value, indicated by [bool].

    [bool] Test() {
        #                     HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\WDSServer\Providers\WDSPXE\Providers\BINLSVC
        $clientsknown = Get-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\WDSServer\Providers\WDSPXE\Providers\BINLSVC -Name "netbootAnswerOnlyValidClients" -ErrorAction SilentlyContinue
        $clientsnone = Get-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\WDSServer\Providers\WDSPXE\Providers\BINLSVC -Name "netbootAnswerRequests" -ErrorAction SilentlyContinue

        if ( $clientsnone.netbootAnswerRequests -eq "FALSE" ) {
            $answerreg = "none"
        }
        elseif ( $clientsknown.netbootAnswerOnlyValidClients -eq "TRUE" ) {
            $answerreg = "known"
        }
        else {
            $answerreg = "all"
        }

        if ($this.Ensure -eq [Ensure]::Present) {
            return $answerreg -eq $this.Answer
        }
        else {
            return $answerreg -eq 'none'
        }
    }

    ## Get the state.  This returns an instance of the class itself, indicated by [MyFolder]

    [cWDSServerAnswer] Get() {
        #
        $clientsnone = Get-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\WDSServer\Providers\WDSPXE\Providers\BINLSVC -Name "netbootAnswerRequests" -ErrorAction SilentlyContinue

        if ( $clientsnone.netbootAnswerRequests -eq "TRUE" ) {
            $this.Ensure = [Ensure]::Present
        }
        else {
            $this.Ensure = [Ensure]::Absent
        }
        return $this
    }
   
}

[DscResource()]  class cDSCModule {
    ##  MyFolder is the name of the resource
    [DscProperty(Mandatory)]
    [Ensure]$Ensure

    [DscProperty(Key)]
    [String]$DSCModule

    ## What to do if it's  not in the right state. This returns nothing, indicated by [void].

    [void] Set() {
        if ($this.Ensure -eq [Ensure]::Present) {
            Install-Module -Name $this.DSCModule -Force
            $module = Get-Module $this.DSCModule -ListAvailable
            $module | Publish-ModuleToPullServer -PullServerWebConfig "$env:SystemDrive\inetpub\PSDSCPullServer\web.config"
        }
        elseif ($this.Ensure -eq [Ensure]::Absent) {
            # remove module
        }
    }

    ## Test to ensure  it's in the right state. This returns a Boolean value, indicated by [bool].

    [bool] Test() {
        #
        if ($null -eq (Get-Module $this.DSCModule -ListAvailable)) {
            return $False
        }
        if ( (Test-Path "C:\pullserver\Modules\$($this.DSCModule)_*.zip") -eq $False ) {
            return $False
        }
        return $true
    }

    ## Get the state.  This returns an instance of the class itself, indicated by [cDSCModule]

    [cDSCModule] Get() {
        #
        $installeddscmodule = Get-Module xPendingReboot -ListAvailable
        return @{
             
            'ModuleVersion' = $installeddscmodule.Version 
        }
    }
}

[DscResource()]  class cVMName {
    ##  MyFolder is the name of the resource
    [DscProperty(Mandatory)]
    [Ensure]$Ensure

    [DscProperty(Key)]
    [String]$DSCModule

    ## What to do if it's  not in the right state. This returns nothing, indicated by [void].

    [void] Set() {
        $regvalue = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Virtual Machine\Guest\Parameters" -Name "VirtualMachineName" -ErrorAction SilentlyContinue
        $Computername = ($regvalue.VirtualMachineName -split ':')[0]
        Rename-Computer -NewName $Computername -Force
    }

    ## Test to ensure  it's in the right state. This returns a Boolean value, indicated by [bool].

    [bool] Test() {
        #
        $regvalue = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Virtual Machine\Guest\Parameters" -Name "VirtualMachineName" -ErrorAction SilentlyContinue
        $Computername = ($regvalue.VirtualMachineName -split ':')[0]
        return ( $env:COMPUTERNAME -eq $Computername)
    }

    ## Get the state.  This returns an instance of the class itself, indicated by [cDSCModule]

    [cVMName] Get() {
        #
        return @{
             
            'ComputerName' = $env:COMPUTERNAME
        }
    }
}

[DscResource()]  class cUnattendXML {
    ##  MyFolder is the name of the resource
    [DscProperty(Mandatory)]
    [Ensure]$Ensure

    [DscProperty(Key)]
    [String]$Filename

    [DscProperty(Mandatory)]
    [pscredential]$WDSCredential

    ## What to do if it's  not in the right state. This returns nothing, indicated by [void].

    [void] Set() {
        $xmlunattend = [xml]'<unattend xmlns="urn:schemas-microsoft-com:unattend">
            <settings pass="windowsPE">
                <component name="Microsoft-Windows-International-Core-WinPE" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
                    <SetupUILanguage>
                        <UILanguage>en-US</UILanguage>
                    </SetupUILanguage>
                    <SystemLocale>en-US</SystemLocale>
                    <UILanguage>en-US</UILanguage>
                    <UserLocale>en-US</UserLocale>
                </component>
                <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
                   <Diagnostics>
                        <OptIn>false</OptIn>
                    </Diagnostics>
                    <DiskConfiguration>
                        <WillShowUI>OnError</WillShowUI>
                        <Disk wcm:action="add">
                            <DiskID>0</DiskID>
                            <WillWipeDisk>true</WillWipeDisk>
                            <CreatePartitions>
                                <CreatePartition wcm:action="add">
                                    <Order>1</Order>
                                    <Size>100</Size>
                                    <Type>EFI</Type>
                                </CreatePartition>
                                <CreatePartition wcm:action="add">
							        <Order>2</Order> 
							        <Type>MSR</Type> 
							        <Size>128</Size> 
                                </CreatePartition>
                                <CreatePartition wcm:action="add">
							        <Order>3</Order> 
							        <Type>Primary</Type> 
							        <Extend>true</Extend> 
                                </CreatePartition>
                            </CreatePartitions>
                            <ModifyPartitions>
                                <ModifyPartition wcm:action="add">
							        <Order>1</Order> 
							        <PartitionID>1</PartitionID> 
							        <Label>System</Label> 
							        <Format>FAT32</Format> 
						        </ModifyPartition>
						        <ModifyPartition wcm:action="add">
							        <Order>2</Order> 
							        <PartitionID>3</PartitionID> 
							        <Label>Local Disk</Label> 
							        <Letter>C</Letter> 
							        <Format>NTFS</Format> 
						        </ModifyPartition>
					        </ModifyPartitions>
                        </Disk>
                    </DiskConfiguration>
                    <ImageInstall>
                        <OSImage>
                            <InstallTo>
                                <DiskID>0</DiskID>
                                <PartitionID>3</PartitionID>
                            </InstallTo>
                            <WillShowUI>OnError</WillShowUI>
                            <InstallToAvailablePartition>false</InstallToAvailablePartition>
                        </OSImage>
                    </ImageInstall>
                    <UserData>
                        <AcceptEula>true</AcceptEula>
                        <FullName></FullName>
                        <Organization></Organization>
                        <ProductKey>
                            <WillShowUI>Never</WillShowUI>
                        </ProductKey>
                    </UserData>
                    <EnableFirewall>true</EnableFirewall>
                    <EnableNetwork>true</EnableNetwork>
                    <WindowsDeploymentServices>
                        <Login>
                            <Credentials>
                                <Username></Username>
                                <Password></Password>
                                <Domain></Domain>
                            </Credentials>
                        </Login>
                        <ImageSelection>
                            <InstallImage>
                                <ImageName></ImageName>
                                <ImageGroup></ImageGroup>
                            </InstallImage>
                            <InstallTo>
                                <DiskID>0</DiskID>
                                <PartitionID>3</PartitionID>
                            </InstallTo>
                        </ImageSelection>
                    </WindowsDeploymentServices>
                </component>
            </settings>
            <settings pass="generalize">
                <component name="Microsoft-Windows-Security-SPP" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
                    <SkipRearm>1</SkipRearm>
                </component>
                <component name="Microsoft-Windows-PnpSysprep" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
                    <PersistAllDeviceInstalls>true</PersistAllDeviceInstalls>
                </component>
                <component name="Microsoft-Windows-IE-InternetExplorer" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
	                <DisableFirstRunWizard>true</DisableFirstRunWizard>
                </component>
            </settings>
            <settings pass="specialize">
                <component name="Microsoft-Windows-Security-SPP-UX" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
                    <SkipAutoActivation>true</SkipAutoActivation>
                </component>
                <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
                    <TimeZone>GMT Standard Time</TimeZone>
                    <ComputerName>TEMPLATE</ComputerName>
                </component>
                <component name="Microsoft-Windows-TerminalServices-LocalSessionManager" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
                    <fDenyTSConnections>false</fDenyTSConnections>
                </component>
                <component name="Microsoft-Windows-TerminalServices-RDP-WinStationExtensions" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
                    <UserAuthentication>0</UserAuthentication>
                </component>
                <component name="Microsoft-Windows-IE-ESC" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
                    <IEHardenAdmin>false</IEHardenAdmin>
                    <IEHardenUser>false</IEHardenUser>
                </component>
                <component name="Microsoft-Windows-ServerManager-SvrMgrNc" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
                    <DoNotOpenServerManagerAtLogon>true</DoNotOpenServerManagerAtLogon>
                </component>
                <component name="Networking-MPSSVC-Svc" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
                    <FirewallGroups>
                        <FirewallGroup wcm:action="add" wcm:keyValue="rd1">
                            <Profile>all</Profile>
                            <Active>true</Active>
                            <Group>Remote Desktop</Group>
                        </FirewallGroup>
                    </FirewallGroups>
                </component>
                <component name="Microsoft-Windows-Deployment" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
                    <RunSynchronous>
                        <RunSynchronousCommand wcm:action="add">
                            <Path>cmd /c md c:\windows\setup\scripts</Path>
                            <Order>1</Order>
                            </RunSynchronousCommand>
                        <RunSynchronousCommand wcm:action="add">
                            <Path>cmd /c echo powershell.exe -command &quot;&amp; {invoke-webrequest -uri &apos;http://wds01/Bootstrap.txt&apos; -OutFile &apos;c:\windows\temp\script.ps1&apos; }&quot; &gt; c:\windows\setup\scripts\setupcomplete.cmd</Path>
                            <Order>2</Order>
                        </RunSynchronousCommand>
                        <RunSynchronousCommand wcm:action="add">
                            <Path>cmd /c echo powershell.exe -command "&amp; {set-executionpolicy bypass -Force }" &gt;&gt; c:\windows\setup\scripts\setupcomplete.cmd</Path>
                            <Order>3</Order>
                        </RunSynchronousCommand>
                        <RunSynchronousCommand wcm:action="add">
                            <Path>cmd /c echo powershell -file c:\windows\temp\script.ps1 &gt;&gt; c:\windows\setup\scripts\setupcomplete.cmd</Path>
                            <Order>4</Order>
                        </RunSynchronousCommand>
                        <RunSynchronousCommand wcm:action="add">
                            <Path>net user administrator /active:yes</Path>
                            <Order>5</Order>
                        </RunSynchronousCommand>
                    </RunSynchronous>
                </component>
            </settings>
            <settings pass="oobeSystem">
                <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
                    <UserAccounts>
                        <AdministratorPassword>
                            <Value/>
                            <PlainText>false</PlainText>
                        </AdministratorPassword>
                    </UserAccounts>
                    <OOBE>
                        <HideEULAPage>true</HideEULAPage>
                        <SkipMachineOOBE>true</SkipMachineOOBE>
                        <SkipUserOOBE>true</SkipUserOOBE>
                        <NetworkLocation>Work</NetworkLocation>
                        <ProtectYourPC>3</ProtectYourPC>
                        <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
                    </OOBE>
                    <TimeZone>W. Europe Standard Time</TimeZone>
                    <DisableAutoDaylightTimeSet>false</DisableAutoDaylightTimeSet>
                </component>
            </settings>
        </unattend>'


        $this.WDSCredential.GetNetworkCredential().password
        $winpe = $xmlunattend.unattend.settings | Where-Object { $_.pass -eq 'windowsPE' }
        $winpe.component.Where( { $_.name -eq 'Microsoft-Windows-International-Core-WinPE' } )
        $winpe.component.Where( { $_.name -eq 'Microsoft-Windows-Setup' } ).WindowsDeploymentServices.Login.Credentials.Username = $this.WDSCredential.GetNetworkCredential().UserName
        $winpe.component.Where( { $_.name -eq 'Microsoft-Windows-Setup' } ).WindowsDeploymentServices.Login.Credentials.Password = $this.WDSCredential.GetNetworkCredential().Password
        $winpe.component.Where( { $_.name -eq 'Microsoft-Windows-Setup' } ).WindowsDeploymentServices.Login.Credentials.Domain = $this.WDSCredential.GetNetworkCredential().Domain

        $xmlunattend.Save( $this.Filename )
    }

    ## Test to ensure  it's in the right state. This returns a Boolean value, indicated by [bool].

    [bool] Test() {
        #
        return ( Test-Path -Path $this.Filename)
    }

    ## Get the state.  This returns an instance of the class itself, indicated by [cDSCModule]

    [cUnattendXML] Get() {
        #
        $status = ''
        $filefound = Test-Path -Path $this.Filename
        if ( $filefound ) {
            $status = $this.Filename
        }

        return @{
             
            'UnattendXML' = $status
        }
    }
}