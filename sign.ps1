<#
.SYNOPSIS
    A simple GUI to load and sign PowerShell scripts.

.DESCRIPTION
    This script demonstrates how to build a Windows Forms-based interface in PowerShell:
      - Button to browse and select a .ps1 file
      - Dropdown to select an available Code Signing certificate from the CurrentUser\My store
      - Button to sign the selected script with the chosen certificate
#>

# --- Load Required Assemblies ---
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Create the Form ---
$form                = New-Object System.Windows.Forms.Form
$form.Text           = "PowerShell Script Signing"
$form.StartPosition  = "CenterScreen"
$form.Size           = New-Object System.Drawing.Size(600,200)
$form.FormBorderStyle= 'FixedDialog'
$form.MaximizeBox    = $false

# --- Label: Script File ---
$lblScript             = New-Object System.Windows.Forms.Label
$lblScript.Text        = "Selected Script:"
$lblScript.AutoSize    = $true
$lblScript.Location    = New-Object System.Drawing.Point(10,20)
$form.Controls.Add($lblScript)

# --- Textbox: Path to Script ---
$txtScript             = New-Object System.Windows.Forms.TextBox
$txtScript.Location    = New-Object System.Drawing.Point(120,15)
$txtScript.Size        = New-Object System.Drawing.Size(340,20)
$txtScript.ReadOnly    = $true
$form.Controls.Add($txtScript)

# --- Button: Browse for Script ---
$btnBrowse             = New-Object System.Windows.Forms.Button
$btnBrowse.Text        = "Browse..."
$btnBrowse.Location    = New-Object System.Drawing.Point(470,13)
$btnBrowse.Size        = New-Object System.Drawing.Size(80,23)

# FileDialog to choose script
$openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
$openFileDialog.Filter = "PowerShell Scripts (*.ps1)|*.ps1"
$openFileDialog.Multiselect = $false

$btnBrowse.Add_Click({
    if ($openFileDialog.ShowDialog() -eq 'OK') {
        $txtScript.Text = $openFileDialog.FileName
    }
})
$form.Controls.Add($btnBrowse)

# --- Label: Certificate ---
$lblCertificate          = New-Object System.Windows.Forms.Label
$lblCertificate.Text     = "Select Certificate:"
$lblCertificate.AutoSize = $true
$lblCertificate.Location = New-Object System.Drawing.Point(10,60)
$form.Controls.Add($lblCertificate)

# --- Combobox: Display Code-Signing Certificates ---
$cmbCertificates            = New-Object System.Windows.Forms.ComboBox
$cmbCertificates.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$cmbCertificates.Location   = New-Object System.Drawing.Point(120,55)
$cmbCertificates.Size       = New-Object System.Drawing.Size(340,20)

# Load Code-Signing certs from CurrentUser\My
$store = New-Object System.Security.Cryptography.X509Certificates.X509Store("My","CurrentUser")
$store.Open("ReadOnly")
$codeSigningCerts = $store.Certificates | Where-Object {
    $_.EnhancedKeyUsageList -ne $null -and
    ($_.EnhancedKeyUsageList | Where-Object { $_.FriendlyName -eq 'Code Signing' })
}
$store.Close()

# Populate combo box with cert Subject or FriendlyName
foreach ($cert in $codeSigningCerts) {
    # Display the Subject or FriendlyName. Adjust as you like.
    $displayName = if ($cert.FriendlyName) { 
        "$($cert.FriendlyName) - [Thumbprint: $($cert.Thumbprint)]" 
    } else {
        "$($cert.Subject) - [Thumbprint: $($cert.Thumbprint)]"
    }
    
    $item = New-Object PSObject -Property @{
        DisplayName = $displayName
        Certificate = $cert
    }
    [void]$cmbCertificates.Items.Add($item)
}

$form.Controls.Add($cmbCertificates)

# --- Button: Sign Script ---
$btnSign              = New-Object System.Windows.Forms.Button
$btnSign.Text         = "Sign Script"
$btnSign.Location     = New-Object System.Drawing.Point(470,53)
$btnSign.Size         = New-Object System.Drawing.Size(80,23)
$btnSign.Enabled      = $true

$btnSign.Add_Click({
    $filePath = $txtScript.Text
    if (-not (Test-Path $filePath)) {
        [System.Windows.Forms.MessageBox]::Show("Please select a valid .ps1 file before signing.","Invalid File",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    
    $selectedCertItem = $cmbCertificates.SelectedItem
    if (-not $selectedCertItem) {
        [System.Windows.Forms.MessageBox]::Show("Please select a Code Signing certificate.","No Certificate Selected",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    $certificate = $selectedCertItem.Certificate
    if (-not $certificate) {
        [System.Windows.Forms.MessageBox]::Show("Could not retrieve the selected certificate.","Certificate Error",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }

    try {
        $signature = Set-AuthenticodeSignature -FilePath $filePath -Certificate $certificate -ErrorAction Stop
        if ($signature.Status -eq 'Valid') {
            [System.Windows.Forms.MessageBox]::Show("Signing succeeded! Script is now signed.","Success",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information)
        } else {
            [System.Windows.Forms.MessageBox]::Show("Script signing completed, but the signature is not valid. Status: $($signature.Status)","Warning",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Warning)
        }
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Error signing script: $($_.Exception.Message)","Error",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error)
    }
})
$form.Controls.Add($btnSign)

# --- Show the Form ---
[void]$form.ShowDialog()
