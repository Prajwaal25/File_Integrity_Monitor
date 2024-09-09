# Load Windows Forms Assembly
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Define Calculate-File-Hash function
Function Calculate-File-Hash($filepath) {
    $filehash = Get-FileHash -Path $filepath -Algorithm SHA512
    return $filehash
}

# Define Erase-Baseline-If-Already-Exists function
Function Erase-Baseline-If-Already-Exists() {
    $baselineExists = Test-Path -Path .\baseline.txt
    if ($baselineExists) {
        # Delete it
        Remove-Item -Path .\baseline.txt
    }
}

# Variable to control the monitoring loop
$global:monitoring = $false

# Create Form
$form = New-Object System.Windows.Forms.Form
$form.Text = "File Monitor"
$form.Size = New-Object System.Drawing.Size(450, 400)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::WhiteSmoke

# Create Label for Folder Path
$label = New-Object System.Windows.Forms.Label
$label.Location = New-Object System.Drawing.Point(10, 20)
$label.Size = New-Object System.Drawing.Size(100, 20)
$label.Text = "Select Folder:"
$form.Controls.Add($label)

# Create TextBox for Folder Path
$textBox = New-Object System.Windows.Forms.TextBox
$textBox.Location = New-Object System.Drawing.Point(120, 20)
$textBox.Size = New-Object System.Drawing.Size(250, 20)
$form.Controls.Add($textBox)

# Create Browse Button
$browseButton = New-Object System.Windows.Forms.Button
$browseButton.Location = New-Object System.Drawing.Point(380, 18)
$browseButton.Size = New-Object System.Drawing.Size(50, 23)
$browseButton.Text = "Browse"
$form.Controls.Add($browseButton)

# Create RadioButton for Collecting Baseline
$radioButtonA = New-Object System.Windows.Forms.RadioButton
$radioButtonA.Location = New-Object System.Drawing.Point(10, 60)
$radioButtonA.Size = New-Object System.Drawing.Size(200, 20)
$radioButtonA.Text = "Collect new Baseline"
$form.Controls.Add($radioButtonA)

# Create RadioButton for Monitoring Files
$radioButtonB = New-Object System.Windows.Forms.RadioButton
$radioButtonB.Location = New-Object System.Drawing.Point(10, 90)
$radioButtonB.Size = New-Object System.Drawing.Size(300, 20)
$radioButtonB.Text = "Begin monitoring files with saved Baseline"
$form.Controls.Add($radioButtonB)

# Create Start Button
$startButton = New-Object System.Windows.Forms.Button
$startButton.Location = New-Object System.Drawing.Point(10, 130)
$startButton.Size = New-Object System.Drawing.Size(75, 23)
$startButton.Text = "Start"
$form.Controls.Add($startButton)


# Create Output TextBox
$outputBox = New-Object System.Windows.Forms.TextBox
$outputBox.Location = New-Object System.Drawing.Point(10, 170)
$outputBox.Size = New-Object System.Drawing.Size(420, 180)
$outputBox.Multiline = $true
$outputBox.ScrollBars = "Vertical"
$form.Controls.Add($outputBox)

# Browse Button Click Event
$browseButton.Add_Click({
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    if ($folderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $textBox.Text = $folderBrowser.SelectedPath
    }
})

# Start Button Click Event
$startButton.Add_Click({
    $filesDirectory = $textBox.Text
    if (-Not (Test-Path -Path $filesDirectory)) {
        [System.Windows.Forms.MessageBox]::Show("The specified folder does not exist.")
        return
    }

    if ($radioButtonA.Checked -eq $true) {
        Erase-Baseline-If-Already-Exists

        $files = Get-ChildItem -Path $filesDirectory
        foreach ($f in $files) {
            $hash = Calculate-File-Hash $f.FullName
            "$($hash.Path)|$($hash.Hash)" | Out-File -FilePath .\baseline.txt -Append
        }
        $outputBox.AppendText("New baseline collected.`n")
    } elseif ($radioButtonB.Checked -eq $true) {
        $global:monitoring = $true
        $fileHashDictionary = @{}
        $filePathsAndHashes = Get-Content -Path .\baseline.txt

        foreach ($f in $filePathsAndHashes) {
            $parts = $f.Split("|")
            $fileHashDictionary[$parts[0]] = $parts[1]
        }

        $outputBox.AppendText("Monitoring started.`n")
        while ($global:monitoring) {
            Start-Sleep -Seconds 1
            $files = Get-ChildItem -Path $filesDirectory

            foreach ($f in $files) {
                $hash = Calculate-File-Hash $f.FullName

                if (-not $fileHashDictionary.ContainsKey($hash.Path)) {
                    $outputBox.AppendText("$($hash.Path) has been created!`n")
                } else {
                    if ($fileHashDictionary[$hash.Path] -ne $hash.Hash) {
                        $outputBox.AppendText("$($hash.Path) has changed!!!`n")
                    }
                }
            }

            foreach ($key in $fileHashDictionary.Keys) {
                $baselineFileStillExists = Test-Path -Path $key
                if (-not $baselineFileStillExists) {
                    $outputBox.AppendText("$($key) has been deleted!`n")
                }
            }
        }
    } else {
        [System.Windows.Forms.MessageBox]::Show("Please select an option.")
    }
})

# Stop Button Click Event
$stopButton.Add_Click({
    $global:monitoring = $false
    $outputBox.AppendText("Monitoring stopped.`n")
})

# Show Form
$form.ShowDialog()
