enum Ensure
{
  Present
  Absent
}

[DscResource()]  class cWDSInitialize ##  MyFolder is the name of the resource
{
    [DscProperty(Mandatory)]
    [Ensure]$Ensure

    [DscProperty(Key)]
    [String]$RootFolder

    ## What to do if it's  not in the right state. This returns nothing, indicated by [void].

    [void] Set() 
    {
        if ($this.Ensure -eq  [Ensure]::Present)
        {
            & wdsutil.exe /initialize-server /reminst:"$($this.RootFolder)" /standalone
            & WDSUTIL.exe /Set-Server /Transport /EnableTftpVariableWindowExtension:No
        }
        elseif ($this.Ensure  -eq [Ensure]::Absent)
        {
            & wdsutil /uninitialize-server
        }
    }

  ## Test to ensure  it's in the right state. This returns a Boolean value, indicated by [bool].

  [bool] Test() 
    {
        #
        $regvalue = Get-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\WDSServer\Providers\WDSTFTP -Name "RootFolder" -ErrorAction SilentlyContinue
        $rootfolderset = $regvalue.RootFolder -eq $this.RootFolder
        if ($this.Ensure -eq  [Ensure]::Present)
        {
            return $rootfolderset
        }
        else
        {
            return -not  $rootfolderset
        }
    }

  ## Get the state.  This returns an instance of the class itself, indicated by [MyFolder]

    [cWDSInitialize] Get() 
    {
        #
        $regvalue = Get-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\WDSServer\Providers\WDSTFTP -Name "RootFolder" -ErrorAction SilentlyContinue
        if( $null -ne $regvalue.RootFolder )
        {
            $this.Ensure = [Ensure]::Present
        }
        else 
        {
            $this.Ensure = [Ensure]::Absent
        }
        return $this
    }
}

[DscResource()]  class cWDSInstallImage ##  MyFolder is the name of the resource
{
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

    ## What to do if it's  not in the right state. This returns nothing, indicated by [void].

    [void] Set() 
    {
        if ($this.Ensure -eq  [Ensure]::Present)
        {
            if( $null -eq $this.GroupName )
            {
                Write-Verbose "Boot image, importing"
                Import-WdsBootImage -Path $this.Path    
            }
            elseif( -not (Get-WdsInstallImageGroup -Name $this.GroupName -ErrorAction SilentlyContinue  ) )
            {
                Write-Verbose "Creating ImageGroup"
                New-WdsInstallImageGroup -Name $this.groupname
                Write-Verbose "Install image, importing"
                Import-WdsInstallImage -Path $this.Path -ImageName $this.ImageName -ImageGroup $this.GroupName
            }
            else
            {
                Write-Verbose "Using existing GroupName"
                Write-Verbose "Install image, importing"
                Import-WdsInstallImage -Path $this.Path -ImageName $this.ImageName -ImageGroup $this.GroupName
            }
            if( $null -ne $this.Unattendfile -and $null -ne $this.GroupName )
            {
                [xml]$xml = Get-Content C:\windows\temp\unattend.xml
                $winpe = $xml.unattend.settings | Where-Object{ $_.pass -eq 'windowsPE' }
                $winpe.component.Where( {$_.name -eq 'Microsoft-Windows-Setup'} ).WindowsDeploymentServices.ImageSelection.InstallImage.ImageName = $this.ImageName
                $winpe.component.Where( {$_.name -eq 'Microsoft-Windows-Setup'} ).WindowsDeploymentServices.ImageSelection.InstallImage.ImageGroup = $this.GroupName
                $xml.Save( "C:\remoteinstall\WdsClientUnattend\$($this.Unattendfile)" )
            }

        }
        elseif ($this.Ensure  -eq [Ensure]::Absent)
        {
            if( $null -eq $this.GroupName )
            {
                Write-Verbose "Removing BootImage"
                Remove-WdsBootImage -ImageName $this.ImageName
            }
            else
            {
                Write-Verbose "Removing InstallImage"
                Remove-WdsInstallImage -ImageName $this.ImageName
            }
        }
    }

  ## Test to ensure  it's in the right state. This returns a Boolean value, indicated by [bool].

  [bool] Test() 
    {
        #
        if( $null -eq $this.GroupName )
        {
            Write-Verbose "Test BootImage"
            $image = Get-WdsBootImage -ImageName $this.ImageName -ErrorAction SilentlyContinue
        }
        else
        {
            Write-Verbose "Test InstallImage"
            $image = Get-WdsInstallImage -ImageName $this.ImageName -ErrorAction SilentlyContinue
        }

        if ($this.Ensure -eq  [Ensure]::Present)
        {
            return $null -ne $image
        }
        else
        {
            return $false
        }
    }

  ## Get the state.  This returns an instance of the class itself, indicated by [MyFolder]

    [cWDSInstallImage] Get() 
    {
        #
        if( $null -eq $this.GroupName )
        {
            Write-Verbose "Get BootImage"
            $image = Get-WdsBootImage -ImageName $this.ImageName -ErrorAction SilentlyContinue
        }
        else
        {
            Write-Verbose "Get InstallImage"
            $image = Get-WdsInstallImage -ImageName $this.ImageName -ErrorAction SilentlyContinue
        }

        if( $null -ne $image.Name )
        {
            $this.Ensure = [Ensure]::Present
        }
        else 
        {
            $this.Ensure = [Ensure]::Absent
        }
        return $this
    }
}

[DscResource()]  class cWDSServerAnswer ##  MyFolder is the name of the resource
{
    [DscProperty(Mandatory)]
    [Ensure]$Ensure

    [DscProperty(Key)]
    [String]$Answer

    ## What to do if it's  not in the right state. This returns nothing, indicated by [void].

    [void] Set() 
    {
        if ($this.Ensure -eq  [Ensure]::Present)
        {
            & wdsutil.exe /set-server /AnswerClients:"$($this.Answer)"
        }
        elseif ($this.Ensure  -eq [Ensure]::Absent)
        {
            & wdsutil /set-server /AnswerClients:none
        }
    }

  ## Test to ensure  it's in the right state. This returns a Boolean value, indicated by [bool].

  [bool] Test() 
    {
        #                     HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\WDSServer\Providers\WDSPXE\Providers\BINLSVC
        $clientsknown = Get-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\WDSServer\Providers\WDSPXE\Providers\BINLSVC -Name "netbootAnswerOnlyValidClients" -ErrorAction SilentlyContinue
        $clientsnone = Get-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\WDSServer\Providers\WDSPXE\Providers\BINLSVC -Name "netbootAnswerRequests" -ErrorAction SilentlyContinue

        if( $clientsnone.netbootAnswerRequests -eq "FALSE" )
        {
            $answerreg = "none"
        }
        elseif( $clientsknown.netbootAnswerOnlyValidClients -eq "TRUE" )
        {
            $answerreg = "known"
        }
        else
        {
            $answerreg = "all"
        }

        if ($this.Ensure -eq  [Ensure]::Present)
        {
            return $answerreg -eq $this.Answer
        }
        else
        {
            return $answerreg -eq 'none'
        }
    }

  ## Get the state.  This returns an instance of the class itself, indicated by [MyFolder]

    [cWDSServerAnswer] Get()  
    {
        #
        $clientsnone = Get-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\WDSServer\Providers\WDSPXE\Providers\BINLSVC -Name "netbootAnswerRequests" -ErrorAction SilentlyContinue

        if( $clientsnone.netbootAnswerRequests -eq "TRUE" )
        {
            $this.Ensure = [Ensure]::Present
        }
        else 
        {
            $this.Ensure = [Ensure]::Absent
        }
        return $this
    }
   
}

[DscResource()]  class cDSCModule ##  MyFolder is the name of the resource
{
    [DscProperty(Mandatory)]
    [Ensure]$Ensure

    [DscProperty(Key)]
    [String]$DSCModule

    ## What to do if it's  not in the right state. This returns nothing, indicated by [void].

    [void] Set() 
    {
        if ($this.Ensure -eq  [Ensure]::Present)
        {
            Install-Module -Name $this.DSCModule -Force
            $module = Get-Module $this.DSCModule -ListAvailable
            $module | Publish-ModuleToPullServer -PullServerWebConfig "$env:SystemDrive\inetpub\PSDSCPullServer\web.config"
        }
        elseif ($this.Ensure  -eq [Ensure]::Absent)
        {
            # remove module
        }
    }

  ## Test to ensure  it's in the right state. This returns a Boolean value, indicated by [bool].

  [bool] Test() 
    {
        #
        if ($null -eq (Get-Module $this.DSCModule -ListAvailable)) {
            return $False
        }
        if( (Test-Path "C:\pullserver\Modules\$($this.DSCModule)_*.zip") -eq $False )
        {
            return $False
        }
        return $true
    }

  ## Get the state.  This returns an instance of the class itself, indicated by [cDSCModule]

    [cDSCModule] Get() 
    {
        #
        $installeddscmodule = Get-Module xPendingReboot -ListAvailable
        return @{
             
            'ModuleVersion' = $installeddscmodule.Version 
        }
    }
}

[DscResource()]  class cVMName ##  MyFolder is the name of the resource
{
    [DscProperty(Mandatory)]
    [Ensure]$Ensure

    [DscProperty(Key)]
    [String]$DSCModule

    ## What to do if it's  not in the right state. This returns nothing, indicated by [void].

    [void] Set() 
    {
        $regvalue = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Virtual Machine\Guest\Parameters" -Name "VirtualMachineName" -ErrorAction SilentlyContinue
        $Computername = ($regvalue.VirtualMachineName -split ':')[0]
        Rename-Computer -NewName $Computername -Force
    }

  ## Test to ensure  it's in the right state. This returns a Boolean value, indicated by [bool].

  [bool] Test() 
    {
        #
        $regvalue = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Virtual Machine\Guest\Parameters" -Name "VirtualMachineName" -ErrorAction SilentlyContinue
        $Computername = ($regvalue.VirtualMachineName -split ':')[0]
        return ( $env:COMPUTERNAME -eq $Computername)
    }

  ## Get the state.  This returns an instance of the class itself, indicated by [cDSCModule]

    [cVMName] Get() 
    {
        #
        return @{
             
            'ComputerName' = $env:COMPUTERNAME
        }
    }
}