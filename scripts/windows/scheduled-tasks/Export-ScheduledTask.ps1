function Export-AllScheduledTasksAsXml {
    param(
        [string]$ExportRoot = "$env:USERPROFILE\Desktop\TaskExports"
    )

    $scheduler = New-Object -ComObject 'Schedule.Service'
    $scheduler.Connect()

    function Export-FolderTasks {
        param (
            [object]$folder,
            [string]$currentPath
        )

        foreach ($subFolder in $folder.GetFolders(0)) {
            $subPath = if ($currentPath) { Join-Path $currentPath $subFolder.Name } else { $subFolder.Name }
            Export-FolderTasks -folder $subFolder -currentPath $subPath
        }

        foreach ($task in $folder.GetTasks(1)) {
            $safeName = ($task.Name -replace '[\\/:*?"<>|]', '_')
            $taskXml = $task.Xml

            $folderPath = if ($currentPath) { Join-Path $ExportRoot $currentPath } else { $ExportRoot }
            if (-not (Test-Path $folderPath)) {
                New-Item -ItemType Directory -Path $folderPath | Out-Null
            }

            $xmlPath = Join-Path $folderPath "$safeName.xml"
            $taskXml | Out-File -LiteralPath $xmlPath -Encoding UTF8
        }
    }

    $rootFolder = $scheduler.GetFolder("\")
    Export-FolderTasks -folder $rootFolder -currentPath ""
    Write-Output "Export abgeschlossen: $ExportRoot"
}
