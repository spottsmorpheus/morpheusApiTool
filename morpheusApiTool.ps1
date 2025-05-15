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
        if ($ApiProfile.GetType().Name -eq "String") {
            try {
                $ApiProfile = $ApiProfile | ConvertFrom-Json
                $Script:ApiProfile = $ApiProfile
            }
            catch {
                Write-Warning "Parameter ApiProfile is not valid Json"
            }
        } elseif ($ApiProfile.GetType().Name -eq "PSCustomObject") {
            $Script:ApiProfile = $ApiProfile 
        } else {
            Write-Warning "Parameter ApiProfile is not s recognised format"
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
            Write-Host "Invoke-Webrequest calls will expect a signed certificate for this profile" -ForegroundColor Yellow
        } else {
            Write-Host "Re-Instating default ServerCertificateValidationCallback" -ForegroundColor Yellow
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
        # Check content type
        if ($response.Headers.item("Content-Type") -match "application/json") {
            Write-Host "StatusCode 200 Response json $($response.Content)" -ForegroundColor Cyan
            $payload = $response.Content | ConvertFrom-Json
            return $payload.access_token
        } else {
            Write-Warning "Check ApplianceUrl : Expecting json response : Unable to get token"
            return $null
        }
    } else {
        Write-Warning "Failed to obtain token: Response StatusCode $($statusCode)"
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
    Morpheus Api Profile object. By default the current profile is used. Use Set-MorpheusApiProfile 
    to set the default ApiProfile

    .PARAMETER EndPoint
    API Endpint - The api endpoint and query parameters. Do not provide the appliance. eg
    api/whoami or /api/instances/5

    .PARAMETER Method
    Method - Defaults to GET

    .PARAMETER PageSize
    If the API enpoint supports paging, this parameter sets the number of objects received per call. 
    This Function will return all objects so choose PageSize carefully.

    .PARAMETER Body
    If required the Body to be sent as payload. Can be an Object or a json string

    .PARAMETER AsJson
    Switch to Accept json Body and Return json payload

    .OUTPUTS
    [PSCustomObject] API response or [String] json if -AsJson parameter specified

    #>      
    [CmdletBinding()]
    param (
        [PSCustomObject]$ApiProfile=$Script:ApiProfile,
        [string]$Endpoint="api/whoami",
        [string]$Method="GET",
        [int]$PageSize=100,
        [Object]$Body=$null,
        [Switch]$AsJson
    )

    # Force Method Uppercase
    $Method = $Method.ToUpper()
    Write-Host "Using Appliance $($ApiProfile.appliance) :SkipCert $($ApiProfile.skipCert)" -ForegroundColor Green
    if ($Endpoint[0] -ne "/") {
        $Endpoint = "/" + $Endpoint
    }
    $Headers = @{"Authorization" = "Bearer $($ApiProfile.token)"; "Content-Type" = "application/json"}
    if ($Body -or $Method -ne "GET" ) {
        Write-Host "Method $Method : Endpoint $EndPoint" -ForegroundColor Green
        if ($Body) {
            # Check the type if its string Then assume its JSON
            if ($Body.GetType().Name -eq "String") {
                # Body is already Specified as JSON String
                $payload = $Body
            } else {
                # Body Object - convert to json payload for the Api (5 levels max
                try {
                    $payload = $Body | Convertto-Json -depth 5 -ErrorAction Stop
                }
                catch {
                    Write-Warning "Failed to convert Payload into JSON"
                    return
                }               
            }
            Write-Host "payload Body:" -ForegroundColor Green
            Write-Host $payload -ForegroundColor Cyan
        } else {
            Write-Warning "No Payload supplied for method $($Method). Request will have no body parameter"
        }
        $params = @{
            Uri="$($ApiProfile.appliance)$($Endpoint)"
            Method=$Method;
            Headers=$Headers;
            ErrorAction="SilentlyContinue"
        }
        if ($Body) {
            $params.Add("Body",$payload)
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
    <#
    .SYNOPSIS
    Returns the Process Event history associated with process types

    - Task, Workflow, Provision or all

    Associated with am InstanceId or ServerId

    .DESCRIPTION
    Returns the Process Event history associated with process types

    - Task, Workflow, Provision or all

    Associated with am InstanceId or ServerId

    .PARAMETER InstanceId

    Returns Process Events for InstanceId

    .PARAMETER ServerId

    Returns Process Events for ServerId

    .PARAMETER ProcessType

    May be one of task, workflow, provision or all

    .PARAMETER AsJson

    Return the output as Json

    .OUTPUTS
    PSCustomObject or Json 
    #> 
    param (
        [int32]$InstanceId=0,
        [int32]$ServerId=0,
        [ValidateSet("task","workflow","provision","all")]
        [string]$ProcessType="all",
        [switch]$AsJson
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
        $returnData =  $proc.processes
    } else {
        $returnData = $proc.processes| Where-Object {$_.processType.name -match $ProcessType}
    }
    if ($AsJson) {
        return $returnData | Convertto-Json -depth 10
    } else {
        return $returnData
    }
}

function Get-MorpheusLogs {
    <#
    .SYNOPSIS
    Returns the Morpheus Health Logs

    .DESCRIPTION
    Returns the Morpheus Health Logs optionally specifying a start and end time

    .PARAMETER Start

    DateTime of DateTime parseable string representing the Date where log records should start

    .PARAMETER End

    DateTime of DateTime parseable string representing the Date where log records should end

    .PARAMETER ProcessType

    May be one of task, workflow, provision or all

    .OUTPUTS
    PSCustomObject
    #> 
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
        Write-Warning "Returning All Health Logs"
        $Response = Invoke-MorpheusApi -Endpoint "/api/health/logs" -PageSize 1000
        $Log = $Response.logs 
        return $Log     
    }
}

function Get-MorpheusEventLogs {
    <#
    .SYNOPSIS
    Returns the Morpheus Health Logs for the timespan covering the Provision of an Instance or Server

    .DESCRIPTION
    Given a Server or Instance ID, this function returns the Health Logs for all the Process Events in the 
    Provision History

    .PARAMETER InstanceId

    Returns Health Logs for timespan covering the provision of InstanceId

    .PARAMETER ServerId

    Returns Health Logs for timespan covering the provision of ServerId

    .OUTPUTS
    PSCustomObject
    #> 
    param (
        [int32]$InstanceId=0,
        [int32]$ServerId=0,
        [switch]$AsJson
    ) 

    #Return and Array
    $provisionEvents = @(Get-MorpheusEvents -InstanceId $InstanceId -ServerId $ServerId -ProcessType "provision")
    if ($provisionEvents) {
        #use ExpandProperty to get Start, End and displayName for the processType
        $null = $provisionEvents | Select-Object -ExpandProperty processType -Property startDate, endDate, displayName
        $processList = $provisionEvents.processType | Sort-Object -Property startDate, endDate
        #Add a minute before and after the forst and last steps to ensure coverage
        $processList[0].startDate = $processList[0].startDate.addMinutes(-1)
        $processList[($processList.count-1)].endDate = $processList[($processList.count-1)].endDate.AddMinutes(1)

        $eventLogs= [System.Collections.Generic.SortedList[int,PSCustomObject]]::new()
        foreach ($process in $processList) {
            if ($process.startDate -AND $process.endDate) {
                Write-Host "Grabbing Logs for Event $($process.displayName)" -ForegroundColor Green
                $logs = Get-MorpheusLogs -Start $process.startDate -End $process.endDate | Sort-Object -Property seq
                Write-Host "Found logs count $($logs.count)" -ForegroundColor Green
                if ($logs.count -gt 0) {
                    foreach ($log in $logs) {
                        $logEvent = [PSCustomObject]@{
                            name=$process.displayName;
                            process=$process.name;
                            #eventStart=$event.startDate;
                            #eventEnd=$event.endDate;
                            logTime=$log.ts;
                            level=$log.level;
                            seqNo=$log.seq;
                            message=$log.message
                        }
                        if (!$eventLogs.ContainsKey($LogEvent.seqNo)) {$eventLogs.Add($LogEvent.seqNo,$logEvent)}
                    }
                } 
            }
        }
        
        if ($AsJson) {
            return $eventLogs.Values | ConvertTo-Json -Depth 5
        } else {
            return $eventLogs.Values
        }
    } else {
        Write-Warning "There are no Health Logs covering this Provision"
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