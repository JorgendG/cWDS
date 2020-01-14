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

    ## What to do if it's  not in the right state. This returns nothing, indicated by [void].

    [void] Set() 
    {
        if ($this.Ensure -eq  [Ensure]::Present)
        {
            if( $this.GroupName -eq $null )
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
        }
        elseif ($this.Ensure  -eq [Ensure]::Absent)
        {
            if( $this.GroupName -eq $null )
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
        if( $this.GroupName -eq $null )
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
            return $image -ne $null
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
        if( $this.GroupName -eq $null )
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
