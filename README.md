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
