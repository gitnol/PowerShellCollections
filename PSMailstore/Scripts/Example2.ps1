﻿<#--------------------------------------------------------------------------

 Example Script 2
 
 for PowerShell Scripting Tutorial
 for MailStore Server 9.1
 
 Requires Microsoft PowerShell 3.0 or higher



 Copyright (c) 2014, 2015 MailStore Software GmbH

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

--------------------------------------------------------------------------#>

Import-Module '..\API-Wrapper\MS.PS.Lib.psd1'

$msapiclient = New-MSApiClient -Username admin -Password admin -MailStoreServer localhost -Port 8463 -IgnoreInvalidSSLCerts
$users = (Invoke-MSApiCall $msapiclient "GetUsers").result
foreach ($user in $users) {(Invoke-MSApiCall $msapiclient "GetUserInfo" @{userName = $user.userName}).result | fl}