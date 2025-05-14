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

You can set up profiles for your appliances and store them in Powershell variables and use the Set-MorpheusApiProfile to easily switch profiles

```
# JSON Profiile
$DevProfile = @"
{
  "appliance": "https://dev.myappliance.com",
  "token": "96af293f-a01b-4cb6-9eb0-fe709xxxxx",
  "skipCert": true
}
"@

# [PSCustomObject] Profile

$ProdProfile = [PSCustomObject]@{
    appliance="https://dev.myappliance.com";
    token="96af293f-a01b-4cb6-9eb0-fe709yyyy";
    skipCert=$false
}
# Set Dev profile
Set-MorpheusApiProfile -ApiProfile $DevProfile

# Set Prod Profile
Set-MorpheusApiProfile -ApiProfile $ProdProfile
```


## Obtaining a Token

Use the function Get-MorpheusApiToken to obtain a Bearer token for the appliance and user credentials.

```

NAME
    Get-MorpheusApiToken
    
SYNOPSIS
    Gets the Morpheus API token for the User Credentials supplied
    
    
SYNTAX
    Get-MorpheusApiToken [[-Appliance] <String>] [[-Credential] <PSCredential>] [<CommonParameters>]
    
    
DESCRIPTION
    Gets the Morpheus API token for the User Credentials supplied
    
    Examples:
    Get-MorpheusApiToken -Appliance <MorpheusApplianceURL> -Credential <PSCredentialObject>
    

PARAMETERS
    -Appliance <String>
        Appliance Name - Defaults to the Script level variable set by Set-MorpheusAppliance
        
    -Credential <PSCredential>
        PSCredential Object - if missing Credentials will be prompted for
        
```

If you do not provide a PSCredential as a parameter the function will prompt for username and password. In the example below the appliance does not have a signed certificate so Skip Certificate checking is setup first

```
Set-PSCertificateCheck -SkipCert

$token = Get-MorpheusApiToken -Appliance "https://myappliancename.com"

PowerShell credential request
Enter Morpheus UI Credentials
User: admin
Password for user admin: *********

Invoking Api https://myappliancename.com/oauth/token?grant_type=password&scope=write&client_id=morph-api
StatusCode 200 Response json {"access_token":"96af293f-a01b-4cb6-9eb0-fe709dbc7xxx","token_type":"bearer","refresh_token":"59363211-6c6d-4777-accd-c00a6b0d55b1","expires_in":857336,"scope":"write"}

$token

96af293f-a01b-4cb6-9eb0-fe709dbc7xxx

#Set up the api profile with the token and in this case skip certificate checking

$MyProfile = Set-MorpheusApiProfile -Appliance "https://myappliancename.com" -Token $token -SkipCert

```

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

Invoke-MorpheusApi without an Endpoint parameter defaults to /api/whoami

```
Invoke-MorpheusApi

Using Appliance https://myappliancename.com :SkipCert True
Method GET : Paging in chunks of 100
Requesting https://myappliancename.com/api/whoami?offset=0&max=100
Page: 0 - 100 
Returning complete payload                                                                                              

user
----                                                                                                                                                                                                                                                                                             
@{id=1; accountId=1; username= ....


```

### Paging is Automatically performed

Invoke-MorpheusApi will always return all items in the PageSize specified (by default 100). This may not always be desirable but unfortunately this is the standard behaviour. Performance issues are mitigated by Paging so choose a PageSize that suits your needs. Responses that return pagable payloads are automatically collated so that the function returns a single collection with all objects


For example to return all Layouts 250 at a time using the current Api profile use the following command

```
$layouts = Invoke-MorpheusApi -Endpoint "/api/library/layouts" -PageSize 250

$layouts =  Invoke-MorpheusApi -Endpoint "/api/library/layouts" -PageSize 250
Using Appliance https://myappliancename.com :SkipCert True
Method GET : Paging in chunks of 250
Requesting https://myappliancename.com/api/library/layouts?offset=0&max=250
Page: 0 - 250 
Requesting https://myappliancename.com/api/library/layouts?offset=250&max=250                          
Page: 250 - 500 of 559
Requesting https://myappliancename.com/api/library/layouts?offset=500&max=250                          
Page: 500 - 750 of 559

# $layouts variable contains collated response from all pages

$layouts.instanceTypeLayouts.count                                            
559


```

if you want the output as JSON use

```
$layouts = Invoke-MorpheusApi -Endpoint "/api/library/layouts" -PageSize 250 -AsJson

```

Posts

```
$grp = @"
{
    "group":
        {
            "name":"DevSystems1",
            "code":"DEVSYS",
            "labels":[
                "DevSystemUK"
            ]
        }
}
"@

# or [PSCustomObject]
$grpObj = [PSCustomObject]@{
    group=[PSCustomObject]@{
        name="DevSystems2";
        code="DEVSYS";
        labels=@("DevSystemUK","DevSystmUS")
    }
}

# Use post with a JSON body add the -AsJson parameter

Invoke-MorpheusApi -Method "POST" -Endpoint "/api/groups" -Body $grp  -AsJson
Using Appliance https://myappliancename.com :SkipCert True
Method POST : Endpoint /api/groups
payload Body:
{
    "group":
        {
            "name":"DevSystems1",
            "code":"DEVSYS",
            "labels":[
                "DevSystemUK"
            ]
        }
}

Success:                                                                                                                
{"group":{"id":5,"uuid":"08b75634-b666-4fe4-a5e2-355c22ec4fbe","name":"DevSystems1","code":"DEVSYS","labels":["DevSystemUK"],"location":null,"accountId":1,"active":true,"config":{},"dateCreated":"2025-05-14T20:24:49Z","lastUpdated":"2025-05-14T20:24:49Z","zones":[],"stats":{"instanceCounts":{"all":0},"serverCounts":{"all":0,"host":0,"hypervisor":0,"containerHost":0,"vm":0,"baremetal":0,"unmanaged":0}},"serverCount":0},"success":true}

# and with the [PSCustomObject]
$status =Invoke-MorpheusApi -Method "POST" -Endpoint "/api/groups" -Body $grpobj

Using Appliance https://myappliancename.com :SkipCert True
Method POST : Endpoint /api/groups
payload Body:
{
  "group": {
    "name": "DevSystems2",
    "code": "DEVSYS",
    "labels": [
      "DevSystemUK",
      "DevSystmUS"
    ]
  }
}
# Access the status
$status | fl                                                                     

group   : @{id=7; uuid=2c0ab64e-f362-4594-96b4-86d013925fbb; name=DevSystems2; code=DEVSYS; labels=System.Object[]; location=; accountId=1; active=True; config=; dateCreated=14/05/2025 20:29:10; lastUpdated=14/05/2025 20:29:10; zones=System.Object[]; stats=; serverCount=0}
success : True

```

## Wrapper Functions

There are some useful functions that wrap the Api calls making them simpler to use. Perhaps the most useful is

```
Get-MorpheusEventLogs

NAME
    Get-MorpheusEventLogs

SYNTAX
    Get-MorpheusEventLogs [[-InstanceId] <int>] [[-ServerId] <int>] [[-ProcessType] {task | workflow | provision | all}] [-AsJson]

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
