enum Ensure
{
  Present
  Absent
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
            elseif( -not (Get-WdsInstallImageGroup -Name $this.GroupName) )
            {
                Write-Verbose "Creating ImageGroup"
                New-WdsInstallImageGroup $this.groupname
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
            $image = Get-WdsBootImage -ImageName $this.ImageName
        }
        else
        {
            Write-Verbose "Test InstallImage"
            $image = Get-WdsInstallImage -ImageName $this.ImageName
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
            $image = Get-WdsBootImage -ImageName $this.ImageName
        }
        else
        {
            Write-Verbose "Get InstallImage"
            $image = Get-WdsInstallImage -ImageName $this.ImageName
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
