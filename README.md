# morpheusApiTool
Powershell Code for wrapping Morpheus API calls (Powershell and Powershell Core)

To load this module directly from GitHub

```
$Uri = "https://raw.githubusercontent.com/spottsmorpheus/morpheusApiTool/main/morpheusApiTool.ps1"
$ProgressPreference = "SilentlyContinue"
# Load Powershell code from GitHub Uri and invoke as a temporary Module
$Response = Invoke-WebRequest -Uri $Uri -UseBasicParsing
if ($Response.StatusCode -eq 200) {
    $Module = New-Module -Name "morpheusApiTool" -ScriptBlock ([ScriptBlock]::Create($Response.Content))
}
```

## Morpheus Api Profile
To use the Powershell functions you must set up an Api profile. The profile can be a Json string or a Powershell [PSCustomObject]. An example of an Api profile in json format is shown here


```
$myJsonProfile = @"
{
  "appliance": "https://example.myappliance.com",
  "token": "96af293f-a01b-4cb6-9eb0-fe709xxxxxx",
  "skipCert": true
}
"@
```

To set an API profile use the Powershell function

```
Set-MorpheusApiProfile -Appliance "https://example.myappliance.com" -Token "96af293f-a01b-4cb6-9eb0-fe709xxxxxx" -SkipCert
```

or use the json object created above

```
Set-MorpheusApiProfile -ApiProfile $myJsonProfile
```

To get the current profile and save this as a [PSCustomObject] use the Function

```
$myProfile = Get-MorpheusApiProfile
```

You can set up profiles for your sappliances and store them in Powershell variables and use the
```
Set-MorpheusApiProfile -ApiProfile $SavedProfile
```
to easily switch profiles

## Invoking Morpheus Api

Use the Powershell Function Invoke-MorpheusApi to make an API call with the current profile

```

NAME
    Invoke-MorpheusApi

SYNOPSIS
    Invokes the Morpheus API call


SYNTAX
    Invoke-MorpheusApi [[-ApiProfile] <PSObject>] [[-Endpoint] <String>] [[-Method] <String>] [[-PageSize] <Int32>] [[-Body] <Object>] [-AsJson]
    [<CommonParameters>]


DESCRIPTION
    Invokes a Morpheus API call for the supplied EndPoint parameter. API calls are paged so
    all the data is returned. The PageSize can be set as a parameter

    Examples:
    Invoke-MoprheusApi -EndPoint "/api/whoami"


PARAMETERS
    -ApiProfile <PSObject>
        Morpheus Api Profile object. By default the current profile is used. Use Set-MorpheusApiProfile
        to set the default ApiProfile

        Required?                    false
        Position?                    1
        Default value                $Script:ApiProfile
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -Endpoint <String>
        API Endpint - The api endpoint and query parameters. Do not provide the appliance. eg
        api/whoami or /api/instances/5

        Required?                    false
        Position?                    2
        Default value                api/whoami
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -Method <String>
        Method - Defaults to GET

        Required?                    false
        Position?                    3
        Default value                GET
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -PageSize <Int32>
        If the API enpoint supports paging, this parameter sets the number of objects received per call.
        This Function will return all objects so choose PageSize carefully.

        Required?                    false
        Position?                    4
        Default value                100
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -Body <Object>
        If required the Body to be sent as payload. Can be an Object or a json string

        Required?                    false
        Position?                    5
        Default value
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -AsJson [<SwitchParameter>]
        Switch to Accept json Body and Return json payload

        Required?                    false
        Position?                    named
        Default value                False
        Accept pipeline input?       false
        Accept wildcard characters?  false


INPUTS

OUTPUTS
    [PSCustomObject] API response or [String] json if -AsJson parameter specified
```

For example to return all instances 200 at a time using the current Api profile use the following command

```
$instances = Invoke-MorpheusApi -Endpoint "/api/instances" -PageSize 200
```

if you want the output as JSON use

```
$instances = Invoke-MorpheusApi -Endpoint "/api/instances" -PageSize 200 -AsJson
```

## Wrapper Functions

There are some useful functions that wrap the Api calls making them simpler to use. Perhaps the most useful is

```
Get-MorpheusEventLogs

NAME
    Get-MorpheusEventLogs

SYNTAX
    ç [[-InstanceId] <int>] [[-ServerId] <int>] [[-ProcessType] {task | workflow | provision | all}] [-AsJson]

```
This function takes an Instance or Server id and extracts all the process steps associated with ProcessType (Default is Provision) and for each step in the process returns the Morpheus Health logs with cover the timespan

For example 

```
$logs = Get-MorpheusEventLogs -InstanceId 77
``` 

returns all the health logs covering the provision timespan of instance with id 77

The list of available fuctions is shown below. Use Powershell Get-Help "function-name" for details 

```
Function        Get-MorpheusApiProfile
Function        Get-MorpheusApiToken
Function        Get-MorpheusEventLogs
Function        Get-MorpheusEvents
Function        Get-MorpheusLayouts
Function        Get-MorpheusLogs
Function        Invoke-MorpheusApi
Function        Set-MorpheusApiProfile
Function        Set-PSCertificateCheck
Function        Show-RoleFeaturePermissions
```

# Generating HTML Output 

Load the HTML Scripts as a dynamic module. Copy and paste into the same Powershell session to make the functions available

```
$Uri = "https://raw.githubusercontent.com/spottsmorpheus/morpheusApiTool/main/outHtml.ps1"
$ProgressPreference = "SilentlyContinue"
# Load Powershell code from GitHub Uri and invoke as a temporary Module
$Response = Invoke-WebRequest -Uri $Uri -UseBasicParsing
if ($Response.StatusCode -eq 200) {
    $Module = New-Module -Name "outHTML" -ScriptBlock ([ScriptBlock]::Create($Response.Content))
}
```

Functions in ths module generate HTLM hat can be viewed in any Browser

Combined with the Morpheus Api functions the output can be rendered into a transportable and easily accessed format

For example to produce a report for the Heath Logs for provision of instance 77 use the following

```
Get-MorpheusEventLogs -InstanceId 77 | Out-HtmlPage -Title "Instance 77 Provision" -Path "./instance77.html"
```

If your Powershell session has access to a Browser then he default browser automatically loads the output
