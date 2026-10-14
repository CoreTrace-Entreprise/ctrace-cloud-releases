# Installs ctrace-cloud from the public releases, checking the SHA-256 checksum and, when cosign
# is on PATH, the signed checksums manifest.
# Usage: irm <install.ps1 url> | iex
# Env: CORETRACE_VERSION (tag such as 0.2.0, default latest), CORETRACE_INSTALL_DIR,
# CORETRACE_DOWNLOAD_URL
& {
  $ErrorActionPreference = 'Stop'
  $ProgressPreference = 'SilentlyContinue'
  [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

  if (-not [Environment]::Is64BitOperatingSystem) { throw 'ctrace-cloud needs 64-bit Windows.' }
  $asset = 'ctrace-cloud-windows-amd64.exe'
  $base = if ($env:CORETRACE_DOWNLOAD_URL) { $env:CORETRACE_DOWNLOAD_URL } else { 'https://github.com/CoreTrace-Entreprise/ctrace-cloud-releases/releases' }
  $dir = if ($env:CORETRACE_INSTALL_DIR) { $env:CORETRACE_INSTALL_DIR } else { Join-Path $env:LOCALAPPDATA 'CoreTrace\bin' }
  $version = $env:CORETRACE_VERSION
  if ($version -and $version -cnotmatch '^v') { $version = "v$version" }
  $url = if ($version) { "$base/download/$version" } else { "$base/latest/download" }
  $label = if ($version) { $version } else { 'latest' }

  $tmp = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid())
  $stage = $null
  try {
    New-Item -ItemType Directory -Path $tmp | Out-Null
    Invoke-WebRequest -UseBasicParsing -Uri "$url/$asset" -OutFile (Join-Path $tmp $asset)
    Invoke-WebRequest -UseBasicParsing -Uri "$url/SHA256SUMS" -OutFile (Join-Path $tmp 'SHA256SUMS')
    $sums = Join-Path $tmp 'SHA256SUMS'
    $hits = @(Get-Content -LiteralPath $sums | Where-Object { ($_ -split '\s+')[1] -ceq $asset })
    if ($hits.Count -ne 1) { throw "SHA256SUMS must list $asset exactly once" }
    $expected = ($hits[0] -split '\s+')[0].ToLower()
    $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $tmp $asset)).Hash.ToLower()
    if ($actual -ne $expected) { throw "checksum mismatch for $asset (expected $expected, got $actual)" }

    if (Get-Command cosign -ErrorAction SilentlyContinue) {
      $bundle = Join-Path $tmp 'SHA256SUMS.sigstore.json'
      Invoke-WebRequest -UseBasicParsing -Uri "$url/SHA256SUMS.sigstore.json" -OutFile $bundle
      & cosign verify-blob --bundle $bundle --certificate-identity-regexp '^https://github.com/CoreTrace-Entreprise/coretrace-cli/\.github/workflows/release\.yml@refs/tags/v[0-9]' --certificate-oidc-issuer https://token.actions.githubusercontent.com $sums
      if ($LASTEXITCODE -ne 0) { throw 'signature check failed for SHA256SUMS' }
    } else {
      Write-Host 'cosign not found, release signature not checked'
    }

    $dir = (New-Item -ItemType Directory -Force -Path $dir).FullName
    $exe = Join-Path $dir 'ctrace-cloud.exe'
    $stage = Join-Path $dir ".ctrace-cloud.$([guid]::NewGuid()).tmp"
    Copy-Item -LiteralPath (Join-Path $tmp $asset) -Destination $stage
    # A running .exe can be renamed but not overwritten, so the old one is moved aside first.
    Remove-Item -LiteralPath "$exe.old" -Force -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $exe) { Move-Item -LiteralPath $exe -Destination "$exe.old" -Force }
    Move-Item -LiteralPath $stage -Destination $exe -Force
    Remove-Item -LiteralPath "$exe.old" -Force -ErrorAction SilentlyContinue
    Write-Host "Installed ctrace-cloud $label to $exe"

    if ([Environment]::OSVersion.Platform -eq 'Win32NT') {
      $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
      $entries = @($userPath -split ';' | Where-Object { $_ })
      if (@($entries | ForEach-Object { $_.TrimEnd('\') }) -notcontains $dir) {
        [Environment]::SetEnvironmentVariable('Path', (@($entries) + $dir) -join ';', 'User')
        Write-Host "Added $dir to your user Path (new terminals pick it up)."
      }
      if (@($env:Path -split ';') -notcontains $dir) { $env:Path = "$env:Path;$dir" }
    }
  } finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    if ($stage) { Remove-Item -LiteralPath $stage -Force -ErrorAction SilentlyContinue }
  }
}
