<#
.SYNOPSIS
    Regressionstest fuer K1 (docs/KNOWN_ISSUES.md): Modulimport vor begin/process
    macht beide Bloecke zu gewoehnlichen Befehlsaufruefen, der Skriptrumpf laeuft nie.
#>

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '../../../scripts/applications/teamviewer/Set-TeamViewerAccess.ps1'
}

Describe 'Set-TeamViewerAccess.ps1 (K1)' {

    It 'enthaelt keinen PSScriptAnalyzer-ParseError (insbesondere InvalidSyntaxAroundProcessBlock)' {
        # -Severity ParseError ist in PSScriptAnalyzer 1.25.0 wirkungslos (liefert
        # immer 0 Treffer, auch wenn echte ParseError-Diagnosen vorliegen) - deshalb
        # ungefiltert aufrufen und selbst filtern.
        $parseErrors = @(Invoke-ScriptAnalyzer -Path $script:ScriptPath | Where-Object Severity -eq 'ParseError')
        $parseErrors | Should -BeNullOrEmpty -Because (
            ($parseErrors | ForEach-Object { "$($_.RuleName) Zeile $($_.Line): $($_.Message)" }) -join '; '
        )
    }

    It 'definiert begin und process als echte Namensbloecke, nicht als Befehlsaufrufe' {
        $tokens = $null
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($script:ScriptPath, [ref]$tokens, [ref]$errors)

        $ast.BeginBlock | Should -Not -BeNullOrEmpty -Because 'begin muss als NamedBlockAst erkannt werden'
        $ast.ProcessBlock | Should -Not -BeNullOrEmpty -Because 'process muss als NamedBlockAst erkannt werden'
    }
}

Describe 'Set-TeamViewerAccess.ps1 (Ausgabe und Parameter)' {

    BeforeAll {
        $script:ScriptPath = Join-Path $PSScriptRoot '../../../scripts/applications/teamviewer/Set-TeamViewerAccess.ps1'
        $tokens = $null
        $errors = $null
        $script:Ast = [System.Management.Automation.Language.Parser]::ParseFile($script:ScriptPath, [ref]$tokens, [ref]$errors)
    }

    It 'bietet -Credential, -GridView, -NoServiceRestart und -WhatIf' {
        $params = $script:Ast.ParamBlock.Parameters.Name.VariablePath.UserPath
        $params | Should -Contain 'Credential'
        $params | Should -Contain 'GridView'
        $params | Should -Contain 'NoServiceRestart'
        $script:Ast.ParamBlock.Attributes.NamedArguments.ArgumentName | Should -Contain 'SupportsShouldProcess'
    }

    It 'ruft Out-GridView nur hinter dem -GridView-Schalter auf' {
        $calls = $script:Ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'Out-GridView' }, $true)
        $calls.Count | Should -Be 1
        $ifAst = $calls[0].Parent
        while ($ifAst -and $ifAst -isnot [System.Management.Automation.Language.IfStatementAst]) { $ifAst = $ifAst.Parent }
        $ifAst.Clauses[0].Item1.Extent.Text | Should -Match '\$GridView'
    }

    It 'meldet offline Rechner statt sie zu verschweigen' {
        $name = "nichtvorhanden-$([guid]::NewGuid().ToString('N').Substring(0,8)).invalid"
        $result = & $script:ScriptPath -ComputerNames $name -AccessControlType 0
        $result.ComputerName | Should -Be $name
        $result.Status | Should -Be 'Offline'
    }
}
