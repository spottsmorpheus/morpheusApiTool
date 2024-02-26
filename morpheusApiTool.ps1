# Script scoped default ApiProfile: Use the function Set-MorpheusApiProfile to configure 

$ApiProfile = [PSCustomObject]@{
    appliance = "Use Set-MorpheusApiProfile -Appliance <url> to set Appliance URL";
    token = "Use Set-MorpheusApiProfile -Token <token> so set the bearer token";
    skipCert = $false
}
# Script level Boolean variable indicates if -SkipCertificateCheck is supported on Invoke-WebRequest calls
$SkipCertSupported = ($PSVersionTable.PSVersion.Major -ge 6)

            # Accept Tls1.1, 1.2
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls12

#Type Declaration for overriding Certs on Windows systems prior to Powershell v6 when -SkipCertificateCheck was introduced
$certCallback = @"
using System;
using System.Net;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;
public class ServerCertificateValidationCallback
{
    public static void Ignore()
    {
        if(ServicePointManager.ServerCertificateValidationCallback ==null)
        {
            ServicePointManager.ServerCertificateValidationCallback += 
                delegate
                (
                    Object obj, 
                    X509Certificate certificate, 
                    X509Chain chain, 
                    SslPolicyErrors errors
                )
                {
                    return true;
                };
        }
    }
}
"@

# Welcome Banner when script is first loaded
$Info=@"
Powershell Version : $($PSVersionTable.PSVersion.ToString())
Platform           : $($PSVersionTable.Platform) - Edition: $($PSVersionTable.PSEdition)

Morpheus API Powershell Functions

Use Set-MorpheusApiProfile to set up the default connection config
To set the default Profile and save it to variable sp use

`$sp = Set-MorpheusApiProfile -Appliance "https://myappliance.net" -Token "c6d785b2-yyyy-46ff-xxxx-9de38068c5bd" -SkipCert 

Use Get-MorpheusApiProfile to ruturn the current Default config

`$myProfile = Get-MorpheusApiConfig

"@

Write-Host $Info -ForegroundColor Green

Write-Warning "Use of -SkipCertificateCheck on Invoke-WebRequest is $(if($SkipCertSupported){'Supported'}else{'Not Supported'})"
Write-Host ""

# Function declaration

function Get-MorpheusApiProfile {
    <#
    .SYNOPSIS
    Returns the current default Morpheus Api Profile object

    .DESCRIPTION
    Returns the current default Morpheus Api Profile object.

    Examples:
    $Profile = Get-MorpheusApiProfile

    Return the current default connection profile

    $newProfile = Get-MorpheusApiProfile -New

    Create a new empty connection profile

    .PARAMETER New

    Returns a new Api Profile object with empty values. Use Set-MorpheusApiProfile to configure

    .PARAMETER AsJson

    Return Api Profile as json object

    .OUTPUTS
    A New Morpheus Api Profile object 
    #> 
    [CmdletBinding()]
    param(
        [Switch]$New,
        [Switch]$AsJson
    )
    
    if ($New) {
        $apiProfile = [PSCustomObject]@{
            appliance = "Use Set-MorpheusApiProfile -Appliance <url> to set Appliance URL";
            token = "Use Set-MorpheusApiProfile -Token <token> so set the bearer token";
            skipCert = $false
        }
    } else {
        $apiProfile = $Script:ApiProfile
    }
    Write-Host "The current default Api Profile" -ForegroundColor Yellow
    Write-Host "Appliance   = $($Script:ApiProfile.appliance)" -ForegroundColor Cyan
    Write-Host "Token       = $($Script:ApiProfile.token)" -ForegroundColor Cyan
    Write-Host "SkipCert    = $($Script:ApiProfile.skipCert)" -ForegroundColor Cyan
    Write-Host ""
    if ($AsJson) {
        return $apiProfile | ConvertTo-Json
    } else {
        return $apiProfile
    }
    
}

function Set-MorpheusApiProfile {
    <#
    .SYNOPSIS
    Sets the Morpheus Api Script configuration Profile

    .DESCRIPTION
    Sets the Morpheus Api Script configuration Profile

    Examples:
    Sets the Morpheus Profile to the connection profile object $config.

    Set-MorpheusApiProfile -ApiProfile $config

    Sets up a connection profile from specific components skipping certificate checks
    Set-MorpheusApiProfile -Appliance <applianceUrl> -Token <token> -SkipCert

    .PARAMETER ApiProfile

    Sets the default profile to the one specified in ApiProfile

    .PARAMETER Appliance

    Sets the default connection profile Appliance property to the one specified

    .PARAMETER Token

    Sets the default connection profile Token property to the one specified

    .PARAMETER SkipCert

    Switch Parameter. If present, sets the default connection profile to ignore Certificate checks 

    .OUTPUTS
    Sets and returns The current Default Connection Profile 
    #>
    [CmdletBinding()]
    param (
        [Object]$ApiProfile,
        [String]$Appliance,
        [String]$Token,
        [Switch]$SkipCert,
        [Switch]$AsJson
    )

    if ($ApiProfile) {
        # Use the Morpheus Api Profile object passed as a parameter as the Default
        if ($AsJson) {
            $Script:ApiProfile = $ApiProfile | ConvertFron-Json
        } else {
            $Script:ApiProfile = $ApiProfile 
        }
    } else {
        # Construct a new Profile from the individual properties (Appliance,Token and SkipCert)
        $apiProfile = Get-MorpheusApiProfile -New
        $apiProfile.appliance = $Appliance
        $apiProfile.token = $Token
        $apiProfile.skipCert = $SkipCert.ToBool()
        $Script:ApiProfile = $apiProfile
    }
    Write-Host "Setting the default Api Profile to:" -ForegroundColor Yellow
    Write-Host "Appliance = $($apiProfile.appliance)" -ForegroundColor Cyan
    Write-Host "Token     = $($apiProfile.token)" -ForegroundColor Cyan
    Write-Host "SkipCert  = $($apiProfile.skipCert)" -ForegroundColor Cyan
    Set-PSCertificateCheck -SkipCert:$apiProfile.skipCert
    return $apiProfile
}


function Set-PSCertificateCheck {
    <#
    .SYNOPSIS
    Optionally overrides SSL Certificate checking on Invoke-WebRequest for Powershell versions without
    built in support

    .DESCRIPTION
    Optionally overrides SSL Certificate checking on Invoke-WebRequest for Powershell versions without
    built in support

    Examples:
    Set-PSCertificateCheck -SkipCert

    Sets Powershell session to ignore Certifiate checks

    .OUTPUTS
    Sets the Script level default API profile property 
    #>
    [CmdletBinding()]
    param (
        [Switch]$SkipCert
    )
    if ($SkipCert) {
        Write-Verbose "Ignoring Certificate errors"
        $Script:ApiProfile.skipCert = $true
        if ($Script:SkipCertSupported) {
            # Native support via -SlikCertificateCheck parameter
            Write-Host "Parameter -SkipCertificateCheck will be used on Invoke-Webrequest for this profile" -ForegroundColor Yellow
        } else {
            # Add support via Custom type
            if (-not ([System.Management.Automation.PSTypeName]'ServerCertificateValidationCallback').Type) {
                # Ignore Self Signed SSL via a custom type
                Add-Type $script:certCallback
            }
            # Ignore Self Signed Certs
            Write-Host "Setting ServerCertificateValidationCallback to ignore Certificate checking" -ForegroundColor Yellow
            [ServerCertificateValidationCallback]::Ignore()
        }      
    } else {
        $Script:ApiProfile.skipCert = $false
        if ($Script:SkipCertSupported) {
            # Native support via -SlikCertificateCheck parameter
            Write-Host "Parameter -SkipCertificateCheck will Not be used on Invoke-Webrequest for this profile" -ForegroundColor Yellow
        } else {
            Write-Host "Re-Instating defualt ServerCertificateValidationCallback" -ForegroundColor Yellow
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $Null
        }
    }
}

function Get-MorpheusApiToken {
    <#
    .SYNOPSIS
    Gets the Morpheus API token for the User Credentials supplied

    .DESCRIPTION
    Gets the Morpheus API token for the User Credentials supplied

    Examples:
    Get-MorpheusApiToken -Appliance <MorpheusApplianceURL> -Credential <PSCredentialObject>

    .PARAMETER Appliance
    Appliance Name - Defaults to the Script level variable set by Set-MorpheusAppliance

    .PARAMETER Credential
    PSCredential Object - if missing Credentials will be prompted for

    .OUTPUTS
    Token : Outputs the API Token

    #>    
    param (
        [string]$Appliance=$script:ApiProfile.appliance,
        [PSCredential]$Credential=$null
    )
    #Credentials can be for Subtenants and if so they are in the form Domain\User where Domain is the Tenant Number 
    if (-Not $credential) {
        $Credential = Get-Credential -message "Enter Morpheus UI Credentials"
    }
    $body = @{username="";password=""}
    $body.username=$Credential.Username
    $body.password=$Credential.GetNetworkCredential().Password
    $uri = "$($Appliance)/oauth/token?grant_type=password&scope=write&client_id=morph-api"
    Write-Host "Invoking Api $($uri)" -ForegroundColor Green
    $params = @{
        Uri=$uri;
        Method="POST";
        Body=$body;
        ContentType="application/x-www-form-urlencoded"
    }
    if ($script:SkipCertSupported) {
        $params.Add("SkipCertificateCheck",$ApiProfile.skipCert)
    }
    try {
        $response = Invoke-WebRequest @params
        $statusCode = $response.StatusCode
    }
    catch {
        Write-Warning $_.Exception.Message
        $statusCode = $_.Exception.Response.StatusCode.value__
        if (-Not $statusCode) {$statusCode=500}        
    }
    if ($statusCode -eq 200) {
        $payload = $response.Content | Convertfrom-Json
        return $payload.access_token
    } else {
        Write-Warning "Response StatusCode $($statusCode)"
        return $null
    }
}

function Invoke-MorpheusApi {
    <#
    .SYNOPSIS
    Invokes the Morpheus API call 

    .DESCRIPTION
    Invokes a Morpheus API call for the supplied EndPoint parameter. API calls are paged so
    all the data is returned. The PageSize can be set as a parameter

    Examples:
    Invoke-MoprheusApi -EndPoint "/api/whoami"

    .PARAMETER ApiProfile
    Morpheus Api Profile object. Use Set-MorpheusVariable

    .PARAMETER EndPoint
    API Endpint - The api endpoint and query parameters

    .PARAMETER Method
    Method - Defaults to GET

    .PARAMETER PageSize
    If the API enpoint supports paging, this parameter sets the size (max API parameter). Defaults to 100

    .PARAMETER Body
    If required the Body to be sent as payload

    .PARAMETER AsJson
    Switch to Accept json Body and Return json payload

    .OUTPUTS
    [PSCustomObject] API response or [String] json if -AsJson parameter specified

    #>      
    [CmdletBinding()]
    param (
        [PSCustomObject]$ApiProfile=$Script:ApiProfile,
        [string]$Endpoint="api/whoami",
        [string]$Method="Get",
        [int]$PageSize=100,
        [Object]$Body=$null,
        [Switch]$AsJson
    )

    Write-Host "Using Appliance $($ApiProfile.appliance) :SkipCert $($ApiProfile.skipCert)" -ForegroundColor Green
    if ($Endpoint[0] -ne "/") {
        $Endpoint = "/" + $Endpoint
    }
    $Headers = @{"Authorization" = "Bearer $($ApiProfile.token)"; "Content-Type" = "application/json"}
    if ($Body -or $Method -ne "Get" ) {
        Write-Host "Method $Method : Endpoint $EndPoint" -ForegroundColor Green
        if ($AsJson) {
            # Body is already Specified as Json
            $payload = $Body
        } else {
            # Body Object - convert to json payload for the Api (5 levels max)
            $payload = $Body | Convertto-json -depth 5                
        }
        Write-Host "payload Body:" -ForegroundColor Green
        Write-Host $payload -ForegroundColor Cyan
        $params = @{
            Uri="$($Appliance)$($Endpoint)"
            Method=$Method;
            Body=$Body;
            Headers=$Headers;
            ErrorAction="SilentlyContinue"
        }
        if ($Script:SkipCertSupported) {
            $params.Add("SkipCertificateCheck",$ApiProfile.skipCert)
        }
        # Use Parameter Splatting
        try {
            $response = Invoke-WebRequest @params
            $statusCode = $response.StatusCode
        }
        catch {
            Write-Warning $_.Exception.Message
            $statusCode = $_.Exception.Response.StatusCode.value__
            if (-Not $statusCode) {$statusCode=500}
        }
        if ($statusCode -eq 200) {
            Write-Host "Success:" -ForegroundColor Green
            if ($AsJson) {
                $payload = $response.Content
            } else {
                $payload = $response.Content | Convertfrom-Json
            }
            return $payload
        } else {
            Write-Warning "API returned status code $($statusCode)"
        }
    } else {
        # Is this for a GET request with no Body - if so prepare to page if necessary
        $page = 0
        $more = $true
        $data = $null
        $total = $null
        Write-Host "Method $Method : Paging in chunks of $PageSize" -ForegroundColor Green
        do {
            if ($Endpoint -match "\?") {
                $url = "$($ApiProfile.appliance)$($Endpoint)&offset=$($page)&max=$($PageSize)"
            } else {
                $url = "$($ApiProfile.appliance)$($Endpoint)?offset=$($page)&max=$($PageSize)"
            }
            Write-Host "Requesting $($url)" -ForegroundColor Green
            Write-Host "Page: $page - $($page+$PageSize) $(if ($total) {"of $total"})" -ForegroundColor Green
            $params = @{
                Uri=$url
                Method=$Method;
                Headers=$Headers;
                ErrorAction="SilentlyContinue"
            }
            if ($Script:SkipCertSupported) {
                $params.Add("SkipCertificateCheck",$ApiProfile.skipCert)
            }
            # Use Parameter Splatting
            try {
                $response=Invoke-WebRequest @params
                $statusCode = $response.StatusCode
            }
            catch {
                Write-Warning $_.Exception.Message
                $statusCode = $_.Exception.Response.StatusCode.value__
                if (-Not $statusCode) {$statusCode=500}
                $more = $false
            }
            if ($statusCode -eq 200) {
                # OK Response - Convert payload from json
                $payload = $response.Content | Convertfrom-Json
                if ($payload.meta) {
                    # Pagable response
                    $total = [Int32]$payload.meta.total
                    $size = [Int32]$payload.meta.size
                    $offset = [Int32]$payload.meta.offset
                    #Response is capable of being paged and contains a meta property. Extract payload
                    $payloadProperty = $payload.PSObject.Properties | Where-Object {$_.name -notmatch "meta"} | Select-Object -First 1
                    $propertyName = $payloadProperty.name
                    if ($Null -eq $data) {
                        # Return the data as PSCustomObject containing the required property
                        $data = [PSCustomObject]@{$propertyName=$payload.$propertyName}
                    } else {
                        $data.$propertyName += $payload.$propertyName
                    }
                    $more = (($offset + $size) -lt $total)
                    $page = $offset + $size
                } else {
                    # Non-Pagable. Return whole response
                    Write-Host "Returning complete payload" -ForegroundColor Green
                    $more = $false
                    $data = $payload
                }                
            } else {
                Write-Warning "API returned status code $($statusCode)"
            }

        } While ($more)
    }
    if ($AsJson) {
        return $data | Convertto-Json -Depth 10
    } else {
        return $data
    }    
}


function Get-MorpheusEvents {
    param (
        [int32]$InstanceId=0,
        [int32]$ServerId=0,
        [ValidateSet("task","workflow","provision","all")]
        [string]$ProcessType="all"
    )

    if ($InstanceId -ne 0) {
        $proc=Invoke-MorpheusApi -Endpoint "/api/processes?instanceId=$($InstanceId)" 
    } elseif ($ServerId -ne 0) {
        $proc=Invoke-MorpheusApi -Endpoint "/api/processes?serverId=$($ServerId)" 
    } else {
        $proc=Invoke-MorpheusApi -Endpoint "/api/processes?refType=container" 
    }
    
    # Filter By ProcessType if required
    if ($ProcessType -eq "all") {
        return $proc.processes
    } else {
        return $proc.processes| Where-Object {$_.processType.name -eq $ProcessType}
    }
}

function Get-MorpheusLogs {
    param (
        [Object]$Start=$null,
        [Object]$End=$null
    )

    if ($Start -And $End) {
        try {
            if ($Start.GetType().name -eq "DateTime") {
                $Start = $Start.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
            } else {
                $Start = [datetime]::parse($Start).toUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
            }
        } Catch {
            Write-Error "Incorrect Time Format $Start"
            return
        }
        try {
            if ($End.GetType().name -eq "DateTime") {
                $End = $End.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
            } else {
                $End = [datetime]::parse($End).toUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
            }
        } Catch {
            Write-Error "Incorrect Time Format $End"
            return
        }       
        Write-Host "Filtering Health Logs: Start $($Start)  - End $($End)"
        $Response = Invoke-MorpheusApi -Endpoint "/api/health/logs?startDate=$($Start)&endDate=$($End)" 
        $Log = $Response.logs 
        return $Log
    } else {
        $Response = Invoke-MorpheusApi -Endpoint "/api/health/logs" -PageSize 1000
        $Log = $Response.logs 
        return $Log     
    }
}

function Get-MorpheusEventLogs {
    param (
        [int32]$InstanceId=0,
        [int32]$ServerId=0,
        [ValidateSet("task","workflow","provision","all")]
        [string]$ProcessType="provision",
        [switch]$AsJson
    ) 

    $provisionEvents =  Get-MorpheusEvents -InstanceId $InstanceId -ServerId $ServerId -ProcessType $ProcessType

    $eventLogs= [System.Collections.Generic.List[Object]]::new()
    foreach ($process in $provisionEvents) {
        foreach ($event in $process.events) {
            if ($event.startDate -AND $event.endDate) {
                Write-Host "Grabbing Logs for Event $($event.displayName) - $($event.processType.name)" -ForegroundColor Green
                $logs = Get-MorpheusLogs -Start $event.startDate -End $event.endDate | Sort-Object -prop seq
                if ($logs.count -gt 0) {
                    foreach ($log in $logs) {
                        $logEvent = [PSCustomObject]@{
                            name=$event.displayName;
                            process=$process.processType.name;
                            eventType=$event.processType.name;
                            #eventStart=$event.startDate;
                            #eventEnd=$event.endDate;
                            logTime=$log.ts;
                            level=$log.level;
                            seqNo=$log.seq;
                            message=$log.message
                        }
                        $eventLogs.Add($logEvent)
                    }
                } else {
                    $logEvent = [PSCustomObject]@{
                        name=$event.displayName;
                        process=$process.processType.name;
                        eventType=$event.processType.name;
                        #eventStart=$event.startDate;
                        #eventEnd=$event.endDate;
                        logTime="";
                        level="";
                        seqNo="";
                        message="No Logs for this TimeSpan"
                    }
                    $eventLogs.Add($logEvent)
                }
            }
        }      
    }

    if ($AsJson) {
        return $eventLogs.ToArray() | ConvertTo-Json -Depth 5
    } else {
        return $eventLogs.ToArray()
    }
}

Function Show-RoleFeaturePermissions {
    [CmdletBinding()]

    $Roles = Invoke-MorpheusApi -Endpoint "/api/roles"
    $UserRoles = $Roles.roles | Where-Object {$_.scope -eq "Account" -And $_.roleType -eq "user"} 
    $RoleData = $UserRoles | ForEach-Object {Invoke-MorpheusApi -Endpoint "/api/roles/$($_.id)"}
    $features = foreach ($role in $RoleData) {
        $Role.featurePermissions | Select-Object -Property @{n="authority";e={$Role.role.authority}},code,name,access
        #$Role.InstanceTypePermissions | Select-Object -Property @{n="authority";e={$Role.role.authority}},code,name,access
    }

    $FeaturePermissionsMatrix=[System.Collections.Generic.List[PSCustomObject]]::new()
    $FeaturePermissions = $features | Group-Object -Property code
    foreach ($f in $FeaturePermissions) {
        $permission = [PSCustomObject]@{feature=$f.name}
        $f.Group | ForEach-Object {Add-Member -InputObject $permission -MemberType NoteProperty -Name $_.authority -Value $_.access}
        $FeaturePermissionsMatrix.Add($Permission)
    }
    $FeaturePermissionsMatrix

}


function Get-MorpheusLayouts {

    $L = Invoke-MorpheusApi -Endpoint "/api/library/layouts" -PageSize 200
    if ($L.instanceTypeLayouts) {
        $Report = $L.instanceTypeLayouts | Foreach-object {
            [PSCustomObject]@{
                instanceTypeId=$_.instanceType.id;
                instanceType=$_.instanceType.name;
                layoutId=$_.id;
                layoutName=$_.name;
                layoutCode=$_.code;
                provisionTypeCode=$_.provisionType.code;
                nodeTypeId = $_.containerTypes.id;
                nodeType = $_.containerTypes.name;
                nodeTypeShortName = $_.containerTypes.shortName;
                imageId = $_.containerTypes.virtualImage.id;
                imageName = $_.containerTypes.virtualImage.name;
            }
        } 
    }
    $Report | Sort-Object -Property instanceType
}