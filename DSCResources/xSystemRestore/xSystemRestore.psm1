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

#Requires -Version 5.0
using namespace System.Globalization

Enum Units
{
    B
    KB
    MB
    GB
    TB
    PB
    EB
}

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
        $Drive,

        [System.String]
        $MaxSize
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

                    if ($PSBoundParameters.ContainsKey('MaxSize'))
                    {
                        if (-not $PSBoundParameters.ContainsKey('Drive'))
                        {
                            throw ([InvalidParametersException]::new('Please specify the Drive property.'))
                        }

                        Set-MaximumShadowCopySize -Drive $Drive -Size $MaxSize -ErrorAction Stop
                    }
                }
                Catch
                {
                    $ErrorMsg = $_.Exception.Message
                    Write-Verbose $ErrorMsg
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
        $Drive,

        [System.String]
        $MaxSize
    )

    #Output the result of Get-TargetResource function.
    $Get = Get-TargetResource -Ensure $Ensure

    If ($Ensure -ne $Get.Ensure)
    {
        return $false
    }

    #When the MaxSize parameter specified, also check capacity size.
    if ($PSBoundParameters.ContainsKey('MaxSize'))
    {
        if (-not $PSBoundParameters.ContainsKey('Drive'))
        {
            throw ([InvalidParametersException]::new('Please specify the Drive property.'))
        }
        else
        {
            $MaxSize = $MaxSize.Trim()
            $CurrentSizeInfo = Get-MaximumShadowCopySize -Drive $Drive -ErrorAction SilentlyContinue

            if (-not $CurrentSizeInfo)
            {
                return $false
            }

            foreach ($info in $CurrentSizeInfo)
            {
                if ($MaxSize -eq 'UNBOUNDED')
                {
                    if ('UNBOUNDED' -ne $info.MaxSizeBytes)
                    {
                        return $false
                    }
                }
                elseif ($MaxSize.EndsWith('%'))
                {
                    if ($MaxSize -ne $info.MaxSizePercent)
                    {
                        return $false
                    }
                }
                else
                {
                    $ConvertedSize = Convert-ByteUnit -String $MaxSize
                    if ($ConvertedSize -ne $info.MaxSizeBytes)
                    {
                        return $false
                    }
                }
            }
        }
    }

    return $true
}

function Convert-ByteStringToDecimal
{
    [CmdletBinding()]
    [OutputType([decimal])]
    Param(
        [Parameter(Mandatory)]
        [string]$String
    )

    $kb = 1024
    $mb = [Math]::Pow($kb, 2)
    $gb = [Math]::Pow($kb, 3)
    $tb = [Math]::Pow($kb, 4)
    $pb = [Math]::Pow($kb, 5)
    $eb = [Math]::Pow($kb, 6)

    [decimal]$Byte = 0
    switch -Regex ($String.Trim())
    {
        '^([0-9\.]+)(kb|k)$'
        {
            $Byte = [Convert]::ToDecimal($Matches[1]) * $kb
            break
        }

        '^([0-9\.]+)(mb|m)$'
        {
            $Byte = [Convert]::ToDecimal($Matches[1]) * $mb
            break
        }

        '^([0-9\.]+)(gb|g)$'
        {
            $Byte = [Convert]::ToDecimal($Matches[1]) * $gb
            break
        }

        '^([0-9\.]+)(tb|t)$'
        {
            $Byte = [Convert]::ToDecimal($Matches[1]) * $tb
            break
        }

        '^([0-9\.]+)(pb|p)$'
        {
            $Byte = [Convert]::ToDecimal($Matches[1]) * $pb
            break
        }

        '^([0-9\.]+)(eb|e)$'
        {
            $Byte = [Convert]::ToDecimal($Matches[1]) * $eb
            break
        }

        '^([0-9]+)$'
        {
            $Byte = [Convert]::ToDecimal($Matches[1])
            break
        }

        Default
        {
            Write-Error -Exception ([System.ArgumentException]::new('Size is not valid format string.'))
            return
        }
    }

    $Byte
}


function Convert-ByteUnit
{
    [CmdletBinding(DefaultParameterSetName = 'Byte')]
    [OutputType([string])]
    Param(
        [Parameter(Mandatory, ParameterSetName = 'String')]
        [string]$String,

        [Parameter(Mandatory, ParameterSetName = 'Decimal')]
        [decimal]$Byte
    )

    $NumStyleFlag = [NumberStyles]::AllowDecimalPoint -bor [NumberStyles]::AllowExponent

    $kb = 1024
    $mb = [Math]::Pow($kb, 2)
    $gb = [Math]::Pow($kb, 3)
    $tb = [Math]::Pow($kb, 4)
    $pb = [Math]::Pow($kb, 5)
    $eb = [Math]::Pow($kb, 6)

    if ($PSCmdlet.ParameterSetName -eq 'String')
    {
        $Byte = Convert-ByteStringToDecimal -String $String
    }

    switch ($true)
    {
        { $Byte -ge $eb }
        {
            $target = $eb
            $unit = [Units]::EB
            break
        }

        { $Byte -ge $pb }
        {
            $target = $pb
            $unit = [Units]::PB
            break
        }

        { $Byte -ge $tb }
        {
            $target = $tb
            $unit = [Units]::TB
            break
        }

        { $Byte -ge $gb }
        {
            $target = $gb
            $unit = [Units]::GB
            break
        }

        { $Byte -ge $mb }
        {
            $target = $mb
            $unit = [Units]::MB
            break
        }

        { $Byte -ge $kb }
        {
            $target = $kb
            $unit = [Units]::KB
            break
        }

        Default
        {
            $target = 1
            $unit = [Units]::B
        }
    }

    $newSize = $Byte / $target
    ([decimal]::parse($newSize.ToString('e2'), $NumStyleFlag)).toString() + ' ' + $unit.ToString()
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
                        MaxSizeBytes   = [regex]::Match($_, ':\s([^\(]+)').Groups[1].Value.Trim()
                        MaxSizePercent = [regex]::Match($_, '\((\d+%)').Groups[1].Value.Trim()
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
    [CmdletBinding(SupportsShouldProcess = $true)]
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
        $Size = $Size.Trim()

        $SizeOfBytes = Convert-ByteStringToDecimal -String $Size -ErrorAction SilentlyContinue
        if ($SizeOfBytes -and ($SizeOfBytes -lt 320MB))
        {
            throw [System.ArgumentOutOfRangeException]::new('For byte level specification, Size must be 320MB or greater')
        }
    }

    Process
    {
        foreach ($driveItem in $Drive)
        {
            if ($PSCmdlet.ShouldProcess("'$driveItem'", "Resize maximum shadow copy storage capacity"))
            {
                try
                {
                    #Resize maximum shadow copy storage capacity
                    Write-Verbose "Resize maximum shadow copy storage capacity on the $driveItem to $Size"
                    $vssoutput = & $vssadmin resize shadowstorage /On=$driveItem /For=$driveItem /MaxSize=$Size
                    if ($LASTEXITCODE -ne 0)
                    {
                        throw [System.InvalidOperationException]::new('Error occurs in vssadmin.exe')
                    }

                    Write-Verbose "Operation Succeeded."
                }
                catch
                {
                    Write-Error -Exception $_.Exception
                }
            }
        }
    }
}

Export-ModuleMember -Function *-TargetResource



