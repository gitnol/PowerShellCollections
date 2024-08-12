<#------------------------------------------------------------------------

 PowerShell Scripting Library
 for MailStore Server and MailStore Service Provider Edition

 Requires Microsoft PowerShell 3.0 or higher



 Copyright (c) 2014 - 2019 MailStore Software GmbH

 Permission is hereby granted, free of charge, to any person obtaining
 a copy of this software and associated documentation files (the
 "Software"), to deal in the Software without restriction, including
 without limitation the rights to use, copy, modify, merge, publish,
 distribute, sublicense, and/or sell copies of the Software, and to
 permit persons to whom the Software is furnished to do so, subject to
 the following conditions:

 The above copyright notice and this permission notice shall be
 included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
 WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

------------------------------------------------------------------------#>

if ($PSVersionTable.PSVersion.Major -lt 3) {
    throw New-Object System.NotSupportedException "PowerShell V3 or higher required."
}

[System.Net.SecurityProtocolType]$DefaultSecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls

<#
.SYNOPSIS
 Scriptblock called by "InternalMSApiCall" to handle long running API processes. 

.DESCRIPTION
 Scriptblock called by "InternalMSApiCall" to handle long running API processes.
 Optionally fires events to notify the parent session of Status changes.
 Returns the final HTTP response as JSON object.
 
.PARAMETER MSApiClient
 MS API client object created by "New-MSApiClient".

.PARAMETER StatusObject
 Initial HTTP answer returned by the API as JSON object.

.PARAMETER StatusTimeout
 Time in milliseconds until the the server stops waiting for a new Status updates to send.

.PARAMETER UseStatusEvents
 If set to true, an event is fired for each status change.

.FUNCTIONALITY
 start-job -ArgumentList <MS API client>, <Initial HTTP response object>, <Timeout>, <UseStatusEvents> -ScriptBlock $sbPullStatus

.LINK
 http://en.help.mailstore.com/MailStore_Server_Administration_API#Long_Running_Processes

.LINK
 http://en.help.mailstore.com/spe/Management_API_-_Using_the_API#Long_Running_Processes

.LINK
 http://en.help.mailstore.com/MailStore_Server_Administration_API#Initial_HTTP_Response
 
.LINK
 http://en.help.mailstore.com/spe/Management_API_-_Using_the_API#Initial_HTTP_Response

.LINK
 http://en.help.mailstore.com/MailStore_Server_Administration_API#HTTP_Response_to_Periodic_Progress_Requests
 
.LINK
 http://en.help.mailstore.com/spe/Management_API_-_Using_the_API#HTTP_Response_to_Periodic_Progress_Requests

.LINK
 http://en.help.mailstore.com/MailStore_Server_Administration_API#Final_HTTP_Response
 
.LINK
 http://en.help.mailstore.com/spe/Management_API_-_Using_the_API#Final_HTTP_Response

.OUTPUTS
 <PSCustomObject>
     JSON object that contains the final HTTP response.

 <PSEngineEvent>
     A custom PowerShell Engine Event that is fired in case of a Status version change. with the following properties: 
     
     -SourceIdentifier <string>
         The initial Status token.
     
     -MessageData <PSCustomObject>
         JSON object with the current Status returned by the server.
#>

$sbPullStatus = [scriptblock]::Create({
    Param(
        [Parameter(Mandatory = $True, Position = 1)]
        [ValidateNotNull()]
        [PSCustomObject]$MSApiClient,
        [Parameter(Mandatory = $True, Position = 2)]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject]$StatusObject,
        [Parameter(Position = 3)]
        [ValidateNotNull()]
        [int]$StatusTimeout = 5000,
        [Parameter(Position = 4)]
        [bool]$UseStatusEvents = $True
    )
    [System.Uri]$StatusUri = New-Object System.Uri ("HTTPS://{0}:{1}/{2}{3}" -f $MSApiClient.Server, $MSApiClient.Port.ToString(), "api/", "get-status")
    
    if ($UseStatusEvents) {

        # The Status token returned by the initial API request identifies the server process. We use it to as event source so the parent PS session knows to which API call the Status relates.
    
        Register-EngineEvent -SourceIdentifier ($StatusObject.token) -Forward
    }
    
    # We need to set ServerCertificateValidationCallback and SecurityProtocol again as this is most likely a new PS session inside a job

    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $MSApiClient.IgnoreInvalidSSLCerts }
    [System.Net.ServicePointManager]::SecurityProtocol = $MSApiClient.SecurityProtocol
    [Microsoft.PowerShell.Commands.WebRequestSession]$Session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    $session.Credentials = $MSApiClient.Credentials

    do {
        $StatusCode = ""

        # We provide the status' token, last known version and a timeout value. The server will wait for that time at most for a new status, therefore it is not necessary for our client process to wait itself.

        $Post = @{token = $StatusObject.token; lastKnownStatusVersion = $StatusObject.statusVersion; millisecondsTimeout = $StatusTimeout}
        try {
            [Microsoft.PowerShell.Commands.BasicHtmlWebResponseObject]$Response = Invoke-WebRequest -Uri $StatusUri.AbsoluteUri -Method Post -Body $Post -WebSession $Session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue
        }
        catch {
            $Response = $global:Error[0].Exception.Response
            if ($Response -eq $null) {
                throw $global:Error[0].Exception
            }
        }
        switch([System.Net.HttpStatusCode]$Response.StatusCode) {
            ([System.Net.HttpStatusCode]::OK) {
                if ($Response.Content -eq $null) {
                    $StatusObject = $null
                    $StatusCode = ""
                } else {

                    # The PS commandlets do not respect the response's encoding, putting the BOM from the server's response into the content field >:-[
                    # We need to remove the BOM so that ConvertFrom-Json succeeds.

                    $null = $Response.RawContentStream.Seek(0, [System.IO.SeekOrigin]::Begin) # Reset the stream
                    $StatusObject  = (New-Object System.IO.StreamReader $Response.RawContentStream, $Response.BaseResponse.CharacterSet).ReadToEnd() | ConvertFrom-Json
                    $StatusCode = $StatusObject.StatusCode

                    # Fire a new PS Engine Event with the status token as SourceIdentifier.
                    # The calling session knows the token and can thus identify to which API call the event relates, especially if there are multiple jobs in the queue.
                    # MessageData contains a return object that has the current status as JSON object in its Data property.
 
                    if ($UseStatusEvents) {
                        $null = New-Event -SourceIdentifier $StatusObject.token -MessageData $StatusObject
                    }
                }
            }
            ([System.Net.HttpStatusCode]::Unauthorized) {
                throw New-Object System.Net.WebException "Authentication failed. Check username and password."
            }
            ([System.Net.HttpStatusCode]::NotFound) {
                throw New-Object System.Net.WebException "Session expired or wrong token."
            }
            default {
                throw New-Object System.Net.WebException ("({0}) {1}: {2}" -f [int]$Response.StatusCode, $Response.StatusDescription , $global:Error[0])
            }
        }
    } while ($StatusCode -eq "running")

    return $StatusObject
})

<#
 Sends an API call to the MailStore or SPE Management Server.

.DESCRIPTION
 Sends an API call to the MailStore or SPE Management Server.
 Optionally runs a call asynchronously through background jobs.
 Returns a JSON <PSCustomObject>.
 
.PARAMETER MSApiClient
 MS API client object created by "New-MSApiClient".

.PARAMETER ApiFunction
 A valid MS API function.

.PARAMETER ApiFunctionParameters
 The parameters for the API function.
 Provide as a hashtable, e.g. @{parameter1 = value1; parameter2 = value2; ...},
 or PSCustomObject with parameters mapped to properties.

.PARAMETER StatusTimeout
 Time in milliseconds until the the server stops waiting for a new status update to send.

.PARAMETER RunAsynchronously
 If provided, an API function that the server decides to run asynchronously is run as a background job.

.LINK
 http://en.help.mailstore.com/MailStore_Server_Administration_API

.LINK
 http://en.help.mailstore.com/spe/Management_API_-_Using_the_API

.LINK
 http://en.help.mailstore.com/MailStore_Server_Administration_API_Commands

.LINK
 http://en.help.mailstore.com/spe/Management_API_-_Function_Reference

.OUTPUTS
 A JSON <PSCustomObject> that encapsulates the HTTP response of the MS server.
#>

function InternalMSApiCall {
    Param(
        [Parameter(Mandatory = $True, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject]$MSApiClient,
        [Parameter(Mandatory = $True, Position = 2)]
        [ValidateScript({$MSApiClient.SupportedApiFunctions.name.Contains($_)})]
        [string]$ApiFunction,
        [Parameter(Position = 3)]
        [System.Object]$ApiFunctionParameters = @{},
        [Parameter(Position = 4)]
        [ValidateNotNull()]
        [int]$StatusTimeout = 5000,
        [Parameter(Position = 5)]
        [switch]$RunAsynchronously
    )

    # If $ApiFunctionParameters is passed as null, use an empty hashtable

    if (!$ApiFunctionParameters) {
       [Hashtable]$ApiFunctionParametersHT = @{}
    } else {

        # If necessary, convert PSCustomObject to Hashtable for further processing

        switch ($ApiFunctionParameters.GetType().Name) {

            "Hashtable" {
                [Hashtable]$ApiFunctionParametersHT = $ApiFunctionParameters
            }

            "PSCustomObject" {
                [Hashtable]$ApiFunctionParametersHT = @{}
                $ApiFunctionParameters.psobject.properties | Foreach { $ApiFunctionParametersHT[$_.Name] = $_.Value }
            }

            default {
                throw New-Object System.ArgumentException ('API function parameters must be passed either as Hashtable or as PSCustomObject.')
            }
        }
    }

    # Get the parameters for the API function supplied. The function itself has been checked in the Param block.

    $MSApiFunctionWithParameters = $MSApiClient.SupportedApiFunctions | Where-Object {$_.name -eq $ApiFunction}
    
    # Check whether the API function requires any parameters at all
    
    if ($MSApiFunctionWithParameters.args.name) {
        [Array]$ParameterNames = $MSApiFunctionWithParameters.args.name
    } else {
        [Array]$ParameterNames = @()
    }

    # Check whether parameters have been supplied that the API function does not support

    [Array]$IllegalParams = Compare-Object -ReferenceObject $ParameterNames -DifferenceObject ([Array]$ApiFunctionParametersHT.Keys) -PassThru | Where-Object {$_.SideIndicator -EQ "=>"}
    
    if ($IllegalParams.Count -gt 0) {
        throw New-Object System.ArgumentException ('Illegal Arguments: {0}' -f ($IllegalParams -join ", "))
    } else {

        # Parameters which have their NULLABLE property set to false are mandatory

        $MSApiFunctionMandatoryParameters = [Array]($MSApiFunctionWithParameters.args | Where-Object {$_.nullable -EQ $false})

        # Check whether any parameters are mandatory at all

        if ($MSApiFunctionMandatoryParameters.name) {
            [Array]$ParameterNames = $MSApiFunctionMandatoryParameters.name
        } else {
            [Array]$ParameterNames = @()
        }

        # Check whether mandatory parameters are missing

        [Array]$MissingParams = Compare-Object -ReferenceObject $ParameterNames -DifferenceObject ([Array]$ApiFunctionParametersHT.Keys) -PassThru | Where-Object {$_.SideIndicator -EQ "<="}
        if ($MissingParams.Count -gt 0) {
            throw New-Object System.ArgumentException ('Missing Arguments: {0}' -f ($MissingParams -join ", "))
        } else {

            #Place Argument Type Check Here. We let the server sort out most of it ;-)

            #Except for Booleans where the server supports only lower case values in compliance with JSON specs

            [Array]$BoolParams = $MSApiFunctionWithParameters.args | Where-Object {$_.type.ToLowerInvariant() -eq "bool"}
            if ($BoolParams.Count -gt 0) {
                [Array]$SuppliedBoolParams = Compare-Object -ReferenceObject $BoolParams.Name -DifferenceObject ([Array]$ApiFunctionParametersHT.Keys) -IncludeEqual -ExcludeDifferent -PassThru
                foreach ($SuppliedBoolParam in $SuppliedBoolParams) {
                    $ApiFunctionParametersHT[$SuppliedBoolParam] = $ApiFunctionParametersHT[$SuppliedBoolParam].ToString().ToLowerInvariant()
                }
            }

            #JSON parameters need to be converted to string if they are supplied as any other type

            [Array]$JSONParams = $MSApiFunctionWithParameters.args | Where-Object {$_.type.ToLowerInvariant() -eq "json"}
            if ($JSONParams.Count -gt 0) {
                [Array]$SuppliedJSONParams = Compare-Object -ReferenceObject $JSONParams.Name -DifferenceObject ([Array]$ApiFunctionParametersHT.Keys) -IncludeEqual -ExcludeDifferent -PassThru
                foreach ($SuppliedJSONParam in $SuppliedJSONParams) {
                    if ($ApiFunctionParametersHT[$SuppliedJSONParam].GetType().Name.ToLowerInvariant() -ne "string") {
                        $ApiFunctionParametersHT[$SuppliedJSONParam] = $ApiFunctionParametersHT[$SuppliedJSONParam] | ConvertTo-Json -Depth 10
                    }
                }
            }

        }
    }

    # If a URI path is defined for the API function, use it, otherwise use the default path

    $functionPath = if ($MSApiFunctionWithParameters | Get-Member "path") { $MSApiFunctionWithParameters.path } else { "api/invoke/" }

    [System.Uri]$Uri = New-Object System.Uri ("HTTPS://{0}:{1}/{2}{3}" -f $MSApiClient.Server, $MSApiClient.Port.ToString(), $functionPath, $ApiFunction)
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $MSApiClient.IgnoreInvalidSSLCerts }
    [System.Net.ServicePointManager]::SecurityProtocol = $MSApiClient.SecurityProtocol
    [Microsoft.PowerShell.Commands.WebRequestSession]$Session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    $Session.Credentials = $MSApiClient.Credentials

    # MS includes a BOM in most of its answers (especially the serialized JSON) which the PS commandlets cannot handle.
    # Therefore we have to use Invoke-WebRequest instead of Invoke-RestMethod and do the parsing ourselves.
    # Redirection and non terminating exceptions are suppressed.

    try {
        [Microsoft.PowerShell.Commands.BasicHtmlWebResponseObject]$Response = Invoke-WebRequest -Uri $Uri.AbsoluteUri -Method Post -Body $ApiFunctionParametersHT -WebSession $Session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue
    }
    catch {
        $Response = $global:Error[0].Exception.Response
        if ($Response -eq $null) {
            throw $global:Error[0].Exception
        }
    }

    # If the web request itself has been successful, we get a StatusCode.

    switch([System.Net.HttpStatusCode]$Response.StatusCode) {
        ([System.Net.HttpStatusCode]::OK) {

            # Respect the response's encoding and thus get rid of the BOM if necessary (see above) so that ConvertFrom-Json succeeds.

            $null = $Response.RawContentStream.Seek(0, [System.IO.SeekOrigin]::Begin) # Reset the stream
            $ResponseObject = (New-Object System.IO.StreamReader $Response.RawContentStream, $Response.BaseResponse.CharacterSet).ReadToEnd() | ConvertFrom-Json
            
            if ($ResponseObject.StatusCode -eq "running") {

                if ($RunAsynchronously.IsPresent) {
                    # For a long running server process, create a background job encapsuled in $sbPullStatus that does the Status handling.

                    $null = Start-Job -ArgumentList $MSApiClient, $ResponseObject, $StatusTimeout, $True -ScriptBlock $sbPullStatus
                } else {
                    $ResponseObject = Invoke-Command -ArgumentList $MSApiClient, $ResponseObject, $StatusTimeout, $False -ScriptBlock $sbPullStatus -NoNewScope
                }
            }

            # Return the JSON response object.

            return $ResponseObject
        }
        ([System.Net.HttpStatusCode]::Unauthorized) {
            throw New-Object System.Net.WebException "Authentication failed. Check username and password."
        }
        default {
            throw New-Object System.Net.WebException ("({0}) {1}: {2}" -f [int]$Response.StatusCode, $Response.StatusDescription , $global:Error[0])
        }
    }
}

<#
.SYNOPSIS
 Creates a new MS API client object.

.DESCRIPTION
 Creates a new MS API client object.
 Returns an MS API client object.
 
.PARAMETER Username
 Username of a MailStore Server or SPE administrator.

.PARAMETER Password
 Password of that MailStore Server or SPE administrator.

.PARAMETER Credentials
 Credentials of a MailStore Server or SPE administrator.
 Alternative to providing <Username> and <Password>.

.PARAMETER MailStoreServer
 DNS name or IP address of the MailStore Server.

.PARAMETER ManagementServer
 DNS name or IP address of the SPE Management Server.

.PARAMETER Port
 Port that the MailStore or SPE Management Server listens to for API calls.

.PARAMETER IgnoreInvalidSSLCerts
 If included, errors due to invalid SSL certificates are ignored.
 If omitted, only certificates that can be validated can be used.

.LINK
 http://en.help.mailstore.com/MailStore_Server_Administration_API_Commands

.LINK
 http://en.help.mailstore.com/spe/Management_API_-_Function_Reference

.OUTPUTS
 <PSCustomObject>
     Object that encapsulates an MS API client instance with the following properties:

     -Server <string>
        Same as MailStoreServer or ManagementServer parameter, see above.

     -Port <string>
        Same as input parameter, see above.

     -IgnoreInvalidSSLCerts <bool>
        Same as input parameter, see above.

     -SupportedApiFunctions <PSCustomObject>
        A JSON object that contains all functions the MS Management Server supports.
        Data fields are:

            -Name <string[]>
                Name of the API function.

            -Args <string[]>
                List of arguments that the API function expects.

            -Path [<string[]>]
                The URI path that a request should use for this function.
                If empty the default path "/invoke/<function>" is used.

        Please refer to http://en.help.mailstore.com/MailStore_Server_Administration_API_Commands
        or http://en.help.mailstore.com/spe/Management_API_-_Function_Reference for futher details.
#>

function New-MSApiClient {
    [CmdletBinding(DefaultParameterSetName="MSSCredentialsAsStringsParameterSet")]
    Param(
        [Parameter(ParameterSetName = "MSSCredentialsAsStringsParameterSet", Position = 1, Mandatory = $true)]
        [Parameter(ParameterSetName = "SPECredentialsAsStringsParameterSet", Position = 1, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Username = "admin",
        [Parameter(ParameterSetName = "MSSCredentialsAsPSCredentialObjectParameterSet", Position = 1, Mandatory = $true)]
        [Parameter(ParameterSetName = "SPECredentialsAsPSCredentialObjectParameterSet", Position = 1, Mandatory = $true)]
        [ValidateNotNull()]
        [pscredential]$Credentials,
        [Parameter(ParameterSetName = "MSSCredentialsAsStringsParameterSet", Position = 2, Mandatory = $true)]
        [Parameter(ParameterSetName = "SPECredentialsAsStringsParameterSet", Position = 2, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Password,
        [Parameter(ParameterSetName = "MSSCredentialsAsStringsParameterSet", Position = 3, Mandatory = $true)]
        [Parameter(ParameterSetName = "MSSCredentialsAsPSCredentialObjectParameterSet", Position = 2, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias("Server")]
        [string]$MailStoreServer = "localhost",
        [Parameter(ParameterSetName = "SPECredentialsAsStringsParameterSet", Position = 3, Mandatory = $true)]
        [Parameter(ParameterSetName = "SPECredentialsAsPSCredentialObjectParameterSet", Position = 2, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ManagementServer = "localhost",
        [Parameter(ParameterSetName = "MSSCredentialsAsStringsParameterSet", Position = 4)]
        [Parameter(ParameterSetName = "SPECredentialsAsStringsParameterSet", Position = 4)]
        [Parameter(ParameterSetName = "MSSCredentialsAsPSCredentialObjectParameterSet", Position = 3)]
        [Parameter(ParameterSetName = "SPECredentialsAsPSCredentialObjectParameterSet", Position = 3)]
        [ValidateRange(1024,65535)]
        [int]$Port,
        [Net.SecurityProtocolType]$SecurityProtocol = $DefaultSecurityProtocol,
        [switch]$IgnoreInvalidSSLCerts
    )

    # If username and password have been provided, store them in a PSCredential object.

    if ($PSBoundParameters.ContainsKey("Password")) {
        $Credentials = New-Object System.Management.Automation.PSCredential($Username,(ConvertTo-SecureString $Password -AsPlainText -Force))
    }

    # Get the server name based on the parameter set used.

    switch -wildcard ($PSCmdlet.ParameterSetName) {
        "MSS*" {
            $Server = $MailStoreServer
        }
        "SPE*" {
            $Server = $ManagementServer
        }
    }
    
    # If no port has been provided, make a best guess based on the server parameter name.

    if (!($PSBoundParameters.ContainsKey("Port"))) {
        switch -wildcard ($PSCmdlet.ParameterSetName) {
            "MSS*" {
            $Port = 8463
            }
            "SPE*" {
            $Port = 8474
            }
        }
    }

    # We provide a basic set of supported API functions to be able to login and initialize the MS API client object. The full set of functions will be retrieved later through "get-metadata" (see below).

    $API_SUPPORTEDFUNCTIONS = '[{"name": "get-status","args": [{"name": "token","type": "string","nullable": false},{"name": "lastKnownStatusVersion","type": "number","nullable": false},{"name": "millisecondsTimeout","type": "number","nullable": false}],"path": "api/"},{"name": "get-metadata","args": [],"path": "api/"},{"name": "cancel-async","args": [{"name": "token","type": "string","nullable": false}],"path": "api/"}]'

    [PSCustomObject]$MSApiClient = @{Credentials = $Credentials; Server = $Server; Port = $Port; SecurityProtocol = $SecurityProtocol; IgnoreInvalidSSLCerts = $IgnoreInvalidSSLCerts.IsPresent; SupportedApiFunctions = $API_SUPPORTEDFUNCTIONS | ConvertFrom-Json}

    # Retrieve a list of all API functions that this installation of MS supports and convert it into a JSON object. Use a parsing depth of 10 levels just be sure and the default of 2 (!) is a bit ... insufficient.

    $SupportedApiFunctions = InternalMSApiCall -MSApiClient $MSApiClient -ApiFunction "get-metadata" | ConvertTo-Json -Depth 10

    # Join our basic set with the retrieved set because "get-metadata" omits some base API functions.

    $MSApiClient.SupportedApiFunctions = ($API_SUPPORTEDFUNCTIONS.Substring(0,$API_SUPPORTEDFUNCTIONS.Length-1) + "," + $SupportedApiFunctions.Substring(1) ) | ConvertFrom-Json

    return $MSApiClient
}

<#
.SYNOPSIS
 Sends an API call to the MailStore or SPE Management Server.

.DESCRIPTION
 Sends an API call to the MailStore or SPE Management Server.
 If the server decides to run the called function asynchronously, this commandlet waits for the final result.
 Use <Start-MSApiCall> for asynchronous function handling.
 Returns a JSON <PSCustomObject>.
 
.PARAMETER MSApiClient
 MS API client object created by "New-MSApiClient".

.PARAMETER ApiFunction
 A valid MS API function.

.PARAMETER ApiFunctionParameters
 The parameters for the API function.
 Provide as a hashtable, e.g. @{parameter1 = value1; parameter2 = value2; ...},
 or PSCustomObject with parameters mapped to properties.

.PARAMETER StatusTimeout
 Time in milliseconds until the the server stops waiting for a new status update to send.

.LINK
 http://en.help.mailstore.com/MailStore_Server_Administration_API

.LINK
 http://en.help.mailstore.com/spe/Management_API_-_Using_the_API

.LINK
 http://en.help.mailstore.com/MailStore_Server_Administration_API_Commands

.LINK
 http://en.help.mailstore.com/spe/Management_API_-_Function_Reference

.OUTPUTS
 A JSON <PSCustomObject> that encapsulates the HTTP response of the MS server.
#>

function Invoke-MSApiCall {
    Param(
        [Parameter(Mandatory = $True, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject]$MSApiClient,
        [Parameter(Mandatory = $True, Position = 2)]
        [ValidateScript({$MSApiClient.SupportedApiFunctions.name.Contains($_)})]
        [string]$ApiFunction,
        [Parameter(Position = 3)]
        [System.Object]$ApiFunctionParameters = @{},
        [Parameter(Position = 4)]
        [ValidateNotNull()]
        [int]$StatusTimeout = 5000
    )

    return InternalMSApiCall -MSApiClient $MSApiClient -ApiFunction $ApiFunction -ApiFunctionParameters $ApiFunctionParameters -StatusTimeout $StatusTimeout
}

<#
.SYNOPSIS
 Sends an API call to the MailStore or SPE Management Server.

.DESCRIPTION
 Sends an API call to the MailStore or SPE Management Server.
 If the server decides to run the called function asynchronously, this commandlet runs the call as a background job.
 Use <Invoke-MSApiCall> for synchronous function handling.
 Returns an object that contains information about the result (see Output).
 
.PARAMETER MSApiClient
 MS API client object created by "New-MSApiClient".

.PARAMETER ApiFunction
 A valid MS API function.

.PARAMETER ApiFunctionParameters
 The parameters for the API function.
 Provide as a hashtable, e.g. @{parameter1 = value1; parameter2 = value2; ...},
 or PSCustomObject with parameters mapped to properties.

.PARAMETER StatusTimeout
 Time in milliseconds until the the server stops waiting for a new status update to send.

.LINK
 http://en.help.mailstore.com/MailStore_Server_Administration_API

.LINK
 http://en.help.mailstore.com/spe/Management_API_-_Using_the_API

.LINK
 http://en.help.mailstore.com/MailStore_Server_Administration_API_Commands

.LINK
 http://en.help.mailstore.com/spe/Management_API_-_Function_Reference

.OUTPUTS
 A JSON <PSCustomObject> that encapsulates the HTTP response of the MS server.
 If that object's <statusCode> property is "running", a Windows PowerShell background job handles the Status of the server process.
 The job fires PSEngineEvents with the status token as SourceIdentifier and the current status in MessageData as a JSON <PSCustomObject>.
 Once the job is finished, it returns the final Status as a JSON <PSCustomObject>.
#>

function Start-MSApiCall {
    Param(
        [Parameter(Mandatory = $True, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject]$MSApiClient,
        [Parameter(Mandatory = $True, Position = 2)]
        [ValidateScript({$MSApiClient.SupportedApiFunctions.name.Contains($_)})]
        [string]$ApiFunction,
        [Parameter(Position = 3)]
        [System.Object]$ApiFunctionParameters = @{},
        [Parameter(Position = 4)]
        [ValidateNotNull()]
        [int]$StatusTimeout = 5000
    )

    return InternalMSApiCall -MSApiClient $MSApiClient -ApiFunction $ApiFunction -ApiFunctionParameters $ApiFunctionParameters -StatusTimeout $StatusTimeout -RunAsynchronously

}
<#
.SYNOPSIS
 Cancels a long running MS server process.

.DESCRIPTION
 Cancels a long running MS server process.
 Returns an object that contains the Status.
 
.PARAMETER MSApiClient
 MS API client object created by "New-MSApiClient".

.PARAMETER AsyncReturnObject
 JSON <PSCustomObject> that encapsulates the initial Status returned by the server in answer to the original API request.

.PARAMETER Token
 The Status token returned by the initial API request.
 Alternative to AsyncReturnObject.

.LINK
 http://en.help.mailstore.com/MailStore_Server_Administration_API#Long_Running_Processes

.LINK
 http://en.help.mailstore.com/spe/Management_API_-_Using_the_API#Long_Running_Processes

.LINK
 http://en.help.mailstore.com/MailStore_Server_Administration_API#Initial_HTTP_Response

.LINK
 http://en.help.mailstore.com/spe/Management_API_-_Using_the_API#Initial_HTTP_Response

.OUTPUTS
 JSON <PSCustomObject> that encapsulates the Status returned by the server.
     
.NOTES
 This function sends an API call to the MailStore or SPE Management Server to request a specific long running process to be cancelled.
 The server decides if and when the cancellation occurs; it does not necessarily cancel the process immediately.
 The background job that does the Status handling continues to run until it receives the server's cancellation signal.
#>

function Stop-MSApiCall {
    Param(
        [Parameter(Mandatory = $True, Position = 1)]
        [ValidateNotNullorEmpty()]
        [PSCustomObject]$MSApiClient,
        [Parameter(ParameterSetName = "JobByObject", Mandatory = $True, Position = 2)]
        [ValidateNotNullorEmpty()]
        [PSCustomObject]$AsyncReturnObject,
        [Parameter(ParameterSetName = "JobByToken", Mandatory = $True, Position = 2)]
        [ValidateNotNullOrEmpty()]
        [string]$Token
    )
    if ($PSCmdlet.ParameterSetName -eq "JobByObject") {
        $Token = $AsyncReturnObject.token
    }
    if ($Token -ne "") {
        return Invoke-MSApiCall $MSApiClient "cancel-async" @{token = $Token}
    }
}

# Aliases to support MailStore SPE 8.5 scripts
# Start-MSSPEApiCall is mapped to Invoke-MSApiCall to assure the correct behavior

Set-Alias -Name New-MSSPEApiClient -Value New-MSApiClient
Set-Alias -Name Invoke-MSSPEApiCall -Value Invoke-MSApiCall
Set-Alias -Name Start-MSSPEApiCall -Value Invoke-MSApiCall
Set-Alias -Name Stop-MSSPEApiCall -Value Stop-MSApiCall

# Aliases to support MailStore Server 7/8 scripts
# Start-MSSApiCall is mapped to Invoke-MSApiCall to assure the correct behavior

Set-Alias -Name New-MSSApiClient -Value New-MSApiClient
Set-Alias -Name Invoke-MSSApiCall -Value Invoke-MSApiCall
Set-Alias -Name Start-MSSApiCall -Value Invoke-MSApiCall

# Public members that should be visible through Import-Module

Export-ModuleMember -Function New-MSApiClient, Invoke-MSApiCall, Start-MSApiCall, Stop-MSApiCall -Alias New-MSSPEApiClient, Invoke-MSSPEApiCall, Start-MSSPEApiCall, Stop-MSSPEApiCall, New-MSSApiClient, Invoke-MSSApiCall, Start-MSSApiCall