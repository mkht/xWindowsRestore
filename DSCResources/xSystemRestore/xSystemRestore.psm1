#---------------------------------------------------------------------------------
#The sample scripts are not supported under any Microsoft standard support
#program or service. The sample scripts are provided AS IS without warranty
#of any kind. Microsoft further disclaims all implied warranties including,
#without limitation, any implied warranties of merchantability or of fitness for
#a particular purpose. The entire risk arising out of the use or performance of
#the sample scripts and documentation remains with you. In no event shall
#Microsoft, its authors, or anyone else involved in the creation, production, or
#delivery of the scripts be liable for any damages whatsoever (including,
#without limitation, damages for loss of business profits, business interruption,
#loss of business information, or other pecuniary loss) arising out of the use
#of or inability to use the sample scripts or documentation, even if Microsoft
#has been advised of the possibility of such damages
#---------------------------------------------------------------------------------

function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateSet("Present", "Absent")]
        [System.String]
        $Ensure
    )

    #Get the status of system restore on the target computer.
    $GetSystemRestore = Get-CimInstance -Class SystemRestoreConfig -Namespace 'root\default'

    $returnValue = @{
        Ensure = $Ensure
    }

    #Check if the system restore is enabled or disabled.
    If ($GetSystemRestore.RPSessionInterval -eq 1)
    {
        $returnValue.Ensure = 'Present'
    }
    Else
    {
        $returnValue.Ensure = 'Absent'
    }

    $returnValue
}


function Set-TargetResource
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateSet("Present", "Absent")]
        [System.String]
        $Ensure,

        [System.String[]]
        $Drive
    )

    Switch ($Ensure)
    {
        'Present'
        {
            If ($PSCmdlet.ShouldProcess("'$Drive'", "Enable the system restore"))
            {
                Try
                {
                    Write-Verbose "Enable the System Restore feature on the '$Drive' file system drive."
                    Enable-ComputerRestore -Drive $Drive -ErrorAction Stop
                }
                Catch
                {
                    $ErrorMsg = $_.Exception.Message
                    Write-Verbose $ErrorMsg
                }
            }
        }
        'Absent'
        {
            If ($PSCmdlet.ShouldProcess("$Drive", "Disable the system restore"))
            {
                Try
                {
                    Write-Verbose "Disable the System Restore feature on the '$Drive' file system drive."
                    Disable-ComputerRestore -Drive $Drive
                }
                Catch
                {
                    $ErrorMsg = $_.Exception.Message
                    Write-Verbose $ErrorMsg
                }
            }
        }
    }
}


function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateSet("Present", "Absent")]
        [System.String]
        $Ensure,

        [System.String[]]
        $Drive
    )

    #Output the result of Get-TargetResource function.
    $Get = Get-TargetResource -Ensure $Ensure

    If ($Ensure -eq $Get.Ensure)
    {
        return $true
    }
    Else
    {
        return $false
    }
}

function Parse-SizeString
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Size
    )

    $ActualSizeString = $null

    #Parse size
    $Size = $Size.Trim()
    if ($Size -eq 'UNBOUNDED')
    {
        #No limit
        $ActualSizeString = $Size.ToUpper()
    }
    elseif ($Size.EndsWith('%'))
    {
        #Percentage
        $tempSize = $Size.Replace('%', '').Trim()
        if ([int]::TryParse($tempSize, [ref]$null))
        {
            $ActualSizeString = $tempSize + '%'
        }

    }
    elseif ($Size -match '^([0-9]+)(kb|mb|gb|tb|pb|eb|k|m|g|t|p|e)$')
    {
        #Bytes with suffix
        $ActualSizeString = $Size
    }

    if ($null -eq $ActualSizeString)
    {
        Write-Error -Exception ([Microsoft.PowerShell.Commands.InvalidParametersException]::new('Size is not valid format string.'))
    }
}


function Get-MaximumShadowCopySize
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.String[]]
        $Drive
    )

    Begin
    {
        $vssadmin = (Get-Command 'vssadmin.exe' -CommandType Application -ErrorAction Stop).Source
    }

    Process
    {
        foreach ($driveItem in $Drive)
        {
            try
            {
                #Get current code page
                $chcp = & chcp
                $CodePage = [int]::Parse([regex]::Match($chcp, ':\s+(\d+)').Groups[1].Value)
                #Change code page to UTF-8 temporarily (for non-english system)
                chcp 65001

                #Invoke vssadmin.exe to get current maximum shadow copy storage capacity
                $vssoutput = & $vssadmin list shadowstorage /On=$driveItem
                if ($LASTEXITCODE -ne 0)
                {
                    throw [System.InvalidOperationException]::new('Error occurs in vssadmin.exe')
                }

                #Parse output of vssadmin.exe
                $vssoutput | Where-Object { $_ -match 'Maximum Shadow Copy Storage space' } | Select-Object -First 1 | ForEach-Object {
                    [pscustomobject]@{
                        Drive          = $driveItem
                        MaxSizeBytes   = [regex]::Match($_, ':\s([^\(]+)').Groups[1].Value
                        MaxSizePercent = [regex]::Match($_, '\(([\d\.]+)%').Groups[1].Value
                    }
                }
            }
            catch
            {
                Write-Error -Exception $_.Exception
            }
            finally
            {
                #Revert code pages
                if ($CodePage -is [int])
                {
                    try
                    {
                        $null = & chcp $CodePage
                    }
                    catch
                    {
                    }
                }
            }
        }
    }
}

function Set-MaximumShadowCopySize
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.String[]]
        $Drive,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Size
    )

    Begin
    {
        $vssadmin = (Get-Command 'vssadmin.exe' -CommandType Application -ErrorAction Stop).Source
        $ActualSizeString = Parse-SizeString -Size $Size -ErrorAction Stop
    }

    Process
    {
        foreach ($driveItem in $Drive)
        {
            try
            {
                #Resize maximum shadow copy storage capacity
                $vssoutput = & $vssadmin resize shadowstorage /On=$driveItem /For=$driveItem /MaxSize=$ActualSizeString
                if ($LASTEXITCODE -ne 0)
                {
                    throw [System.InvalidOperationException]::new('Error occurs in vssadmin.exe')
                }
            }
            catch
            {
                Write-Error -Exception $_.Exception
            }
        }
    }
}

Export-ModuleMember -Function *-TargetResource



