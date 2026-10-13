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
