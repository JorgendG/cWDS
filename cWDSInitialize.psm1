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