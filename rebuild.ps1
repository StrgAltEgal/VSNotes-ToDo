# Functions for colored output
function Write-Status {
    param([string]$Message)
    Write-Host "[STATUS] " -ForegroundColor Blue -NoNewline
    Write-Host $Message
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] " -ForegroundColor Green -NoNewline
    Write-Host $Message
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] " -ForegroundColor Yellow -NoNewline
    Write-Host $Message
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] " -ForegroundColor Red -NoNewline
    Write-Host $Message
}

# Debug: Show environment information
Write-Debug "PowerShell Version: $($PSVersionTable.PSVersion)"
Write-Debug "Current Directory: $(Get-Location)"
Write-Debug "Script Path: $PSCommandPath"

# Stop Cursor if it's running
Write-Status "Checking if Cursor is running..."
$cursorProcess = Get-Process "Cursor" -ErrorAction SilentlyContinue
if ($cursorProcess) {
    Write-Debug "Found Cursor process with ID: $($cursorProcess.Id)"
    Stop-Process -InputObject $cursorProcess -Force
    Write-Debug "Cursor process stopped"
} else {
    Write-Debug "No Cursor process found running"
}
Start-Sleep -Seconds 2

# Update dependencies
Write-Status "Updating dependencies..."
Write-Debug "Running npm install..."
$npmOutput = npm install 2>&1
Write-Debug "npm install output:"
$npmOutput | ForEach-Object { Write-Debug $_ }
Write-Success "Dependencies updated"

# Create new VSIX package
Write-Status "Creating new VSIX package..."
Write-Debug "Running vsce package..."
$vsceOutput = vsce package 2>&1
Write-Debug "vsce package output:"
$vsceOutput | ForEach-Object { Write-Debug $_ }
Write-Success "VSIX package created"

# Uninstall old extension
Write-Status "Uninstalling old extension..."
$cursorExtensionsPath = "$env:USERPROFILE\.cursor\extensions"
Write-Debug "Extensions path: $cursorExtensionsPath"

$extensionFolder = Get-ChildItem -Path $cursorExtensionsPath -Filter "mafut.vsc-treeviewchecklist*" -Directory -ErrorAction SilentlyContinue
if ($extensionFolder) {
    Write-Debug "Found existing extension at: $($extensionFolder.FullName)"
    Remove-Item -Path $extensionFolder.FullName -Recurse -Force
    Write-Success "Old extension uninstalled"
} else {
    Write-Debug "No existing extension found"
    Write-Warning "No old extension found to uninstall"
}

# Install new extension
Write-Status "Installing new extension..."
$vsixFile = "vsc-treeviewchecklist-0.1.8.vsix"
$targetExtensionPath = "$cursorExtensionsPath\mafut.vsc-treeviewchecklist-0.1.8"

Write-Debug "VSIX file path: $(Resolve-Path $vsixFile -ErrorAction SilentlyContinue)"
if (!(Test-Path $vsixFile)) {
    Write-Error "VSIX file not found at: $vsixFile"
    exit 1
}

if (!(Test-Path $cursorExtensionsPath)) {
    Write-Debug "Creating extensions directory: $cursorExtensionsPath"
    New-Item -Path $cursorExtensionsPath -ItemType Directory -Force
}

# Create a temporary directory for extraction
$tempDir = Join-Path $env:TEMP "vsix_extract_$(Get-Random)"
Write-Debug "Creating temporary directory: $tempDir"
New-Item -Path $tempDir -ItemType Directory -Force

# Copy VSIX to ZIP and extract
$zipFile = Join-Path $tempDir "extension.zip"
Write-Debug "Copying $vsixFile to $zipFile"
Copy-Item -Path $vsixFile -Destination $zipFile -Force

Write-Debug "Extracting to temp directory: $tempDir"
Expand-Archive -Path $zipFile -DestinationPath $tempDir -Force

# Create the final extension directory
Write-Debug "Creating extension directory: $targetExtensionPath"
New-Item -Path $targetExtensionPath -ItemType Directory -Force

# Move the extension files to the correct location
Write-Debug "Moving extension files to: $targetExtensionPath"
Copy-Item -Path "$tempDir\extension\*" -Destination $targetExtensionPath -Recurse -Force

# Cleanup
Write-Debug "Cleaning up temporary files"
Remove-Item -Path $tempDir -Recurse -Force
Write-Success "New extension installed"

# Verify installation
Write-Debug "Verifying installation..."
if (Test-Path "$targetExtensionPath\extension.js") {
    Write-Debug "extension.js found"
} else {
    Write-Error "extension.js not found!"
}

if (Test-Path "$targetExtensionPath\package.json") {
    Write-Debug "package.json found"
} else {
    Write-Error "package.json not found!"
}

# Start Cursor
Write-Status "Starting Cursor..."
Start-Process cursor -ArgumentList "."

Write-Success "Rebuild complete! Cursor has been restarted."
Write-Host "`nDebug Information:"
Write-Host "1. Extension path: $targetExtensionPath"
Write-Host "2. Check extension files exist: $(Test-Path $targetExtensionPath)"
Write-Host "3. Check package.json exists: $(Test-Path "$targetExtensionPath\package.json")"
Write-Host "4. Check extension.js exists: $(Test-Path "$targetExtensionPath\extension.js")"

Write-Host "`nIf you encounter any issues:"
Write-Host "1. Make sure Cursor is fully loaded"
Write-Host "2. Use Ctrl+Shift+P and run 'Developer: Reload Window'"
Write-Host "3. Check the output panel for any error messages"
Write-Host "4. Check the Developer Tools console (Ctrl+Shift+I) for any JavaScript errors"
Write-Host "5. Verify the extension path exists: $targetExtensionPath"
Write-Host "6. Check if all required files are present in the extension directory"

Write-Host "`nPress any key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") 