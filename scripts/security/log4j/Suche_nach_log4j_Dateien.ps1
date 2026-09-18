# Todo ... automatisches Löschen implementieren per Flag...ggf mit einer Filelist Denylist oder Allowlist
# log4j-core-2.15.0.jar
# log4j-core-2.16*

$like_case = "*jndilookup.class*"
$zieldatei = "C:\install\log4j_$env:computername.txt"

if ($PSVersionTable.PSVersion.Major -le 2) {
	$PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
	$pfad_zu_7_zip = ($PSScriptRoot + "\7z.exe")
}
else {
	$pfad_zu_7_zip = ($PSScriptRoot + "\7z.exe")
}

Function Execute-Command ($commandTitle, $commandPath, $commandArguments) {
	Try {
		$pinfo = New-Object System.Diagnostics.ProcessStartInfo
		$pinfo.FileName = $commandPath
		$pinfo.RedirectStandardError = $true
		$pinfo.RedirectStandardOutput = $true
		$pinfo.UseShellExecute = $false
		$pinfo.Arguments = $commandArguments
		$pinfo.StandardOutputEncoding = [System.Text.Encoding]::GetEncoding(1252) # Wichtig... damit Umlaute erkannt werden.
		$p = New-Object System.Diagnostics.Process
		$p.StartInfo = $pinfo
		$p.Start() | Out-Null
		[pscustomobject]@{
			commandTitle = $commandTitle
			stdout       = $p.StandardOutput.ReadToEnd()
			stderr       = $p.StandardError.ReadToEnd()
			ExitCode     = $p.ExitCode
		}
		$p.WaitForExit()
	}
	Catch {
		write-host "Es ist ein Fehler in Funktion Execute-Command aufgetreten."
		exit
	}
}

function teste_jar_file($jarfile, $like_case) {
	# $cmdOutput = ((Execute-Command -commandTitle ("7-zip Listing " +  $jarfile.Name) -commandPath "D:\Downloads\7-ZipPortable\App\7-Zip64\7z.exe" -commandArguments (" l """ +$jarfile.FullName + """")).stdout).split("`n")
	$cmdOutput = ((Execute-Command -commandTitle ("7-zip Listing " + $jarfile.Name) -commandPath $pfad_zu_7_zip -commandArguments (" l """ + $jarfile.FullName + """")).stdout).split("`n")
	if ($cmdOutput | where-Object { $_ -like $like_case }) {
		# Gibt ein Array mit allen Pfaden auf dem aktuellen Rechner innerhalb der JAR Datei zurück, auf die der like_case zutrifft.
		return ($env:computername + "`t" + $jarfile.FullName + "`t" + ($cmdOutput | where-Object { $_ -like $like_case }).split("  ")[-1]).Trim()
	}
}

# teste_jar_file -jarfile (gci "C:\install\log4j_test_entfernen\com.ibm.ws.webservices.thinclient_7.0.0 Kopie.jar") -like_case "*jndilookup.class*" # Positivbeispiel
# teste_jar_file -jarfile (gci "C:\install\log4j_test_entfernen\com.ibm.ws.webservices.thinclient_7.0.0.jar") -like_case "*jndilookup.class*" # Negativbeispiel.

Write-Host "Aktueller Host: $env:computername"

# Prüfen, ob die Datei existiert und falls ja, dann löschen.
if (Test-Path $zieldatei -PathType Leaf) {
	remove-item -Path $zieldatei -Force
}

#Programmstart

$lokale_laufwerke = ([System.IO.DriveInfo]::GetDrives() | Where-Object { $_.DriveType -eq 'Fixed' } | Select-Object Name).Name

ForEach ($laufwerk in $lokale_laufwerke) {
	
	
	if ($PSVersionTable.PSVersion.Major -le 2) {
		Get-ChildItem -Path $laufwerk -Include ('*.jar', '*.war') -Recurse -Force -ErrorAction SilentlyContinue | where-object { ! $_.PSIsContainer } | ForEach-Object {
			# Write-Host "." -NoNewLine
			Write-Host $_.Fullname
			$ergebnis = (teste_jar_file -jarfile $_ -like_case $like_case)
			$ergebnis # für die Scriptausgabe
			$ergebnis | Add-Content $zieldatei
		}
	}
 else {
		Get-ChildItem -Path $laufwerk -Include ('*.jar', '*.war') -File -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
			# Write-Host "." -NoNewLine
			Write-Host $_.Fullname
			$ergebnis = (teste_jar_file -jarfile $_ -like_case $like_case)
			$ergebnis # für die Scriptausgabe
			$ergebnis | Add-Content $zieldatei
		}
	}
}

