#requires -Version 5.1
<#
.SYNOPSIS
    Build the Frag95 ISO inside a privileged Arch Linux Docker container.

.DESCRIPTION
    Convenience wrapper for native-Windows PowerShell users. It builds (or
    reuses) the frag95-builder image, then runs mkarchiso in a privileged
    container with loop-device access. Output ISO is written to .\out\.

    This is NOT the only way to build: build.sh is the cross-platform entrypoint
    (Linux / macOS / WSL / Git Bash; docker or podman; plus a native no-container
    path on Arch). build.ps1 and build.sh produce the same ISO via the same
    container scripts. On Windows you can use either this script or, under WSL or
    Git Bash, `./build.sh`.

.PARAMETER Rebuild
    Force a rebuild of the frag95-builder Docker image.

.PARAMETER Test
    After building, run the QEMU boot smoke test (scripts/qemu-test.sh).
#>
[CmdletBinding()]
param(
    [switch]$Rebuild,
    [switch]$Test
)

$ErrorActionPreference = 'Stop'
$repo = (Get-Location).Path
$image = 'frag95-builder'

# Sanity: Docker must be available.
& docker version *> $null
if ($LASTEXITCODE -ne 0) {
    throw "Docker is not available. Start Docker Desktop and try again."
}

# Build the builder image if missing or if -Rebuild was passed.
$exists = (& docker images -q $image)
if ($Rebuild -or [string]::IsNullOrWhiteSpace($exists)) {
    Write-Host "==> Building Docker builder image '$image'..." -ForegroundColor Cyan
    & docker build -t $image -f "$repo\docker\Dockerfile.builder" "$repo\docker"
    if ($LASTEXITCODE -ne 0) { throw "Docker image build failed." }
} else {
    Write-Host "==> Reusing existing '$image' image (use -Rebuild to refresh)." -ForegroundColor DarkGray
}

# Ensure output dir exists.
New-Item -ItemType Directory -Force -Path "$repo\out" | Out-Null

Write-Host "==> Running mkarchiso (privileged container)..." -ForegroundColor Cyan
# Named volume persists pacman's package cache across builds (avoids re-downloading ~1.8GB).
& docker run --rm --privileged `
    -v "${repo}:/repo" `
    -v "${repo}\out:/out" `
    -v "frag95-pacman-cache:/var/cache/pacman/pkg" `
    -e REPO=/repo -e WORK=/work -e OUT=/out `
    $image `
    /repo/scripts/build-in-container.sh
if ($LASTEXITCODE -ne 0) { throw "ISO build failed." }

Write-Host "==> Build complete. ISO is in .\out\" -ForegroundColor Green
Get-ChildItem "$repo\out\*.iso" | Select-Object Name, @{N='SizeMB';E={[math]::Round($_.Length/1MB)}}

if ($Test) {
    Write-Host "==> Running QEMU boot smoke test..." -ForegroundColor Cyan
    & docker run --rm --privileged `
        -v "${repo}:/repo" `
        -v "${repo}\out:/out" `
        $image `
        /repo/scripts/qemu-test.sh
    if ($LASTEXITCODE -ne 0) { throw "QEMU smoke test failed." }
}
