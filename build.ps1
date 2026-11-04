# Builds the Toondio voice engine release zip: the program, the sherpa-onnx
# 1.13.8 Windows DLLs (unchanged, from the pub cache) and the licenses.
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$version = (Select-String -Path "$here\pubspec.yaml" -Pattern '^version: (.+)$').Matches[0].Groups[1].Value
$out = "$here\build\toondio-voice-engine"
$dlls = "$env:LOCALAPPDATA\Pub\Cache\hosted\pub.dev\sherpa_onnx_windows-1.13.8\windows"
if (Test-Path $out) { Remove-Item $out -Recurse -Force }
New-Item -ItemType Directory -Force $out | Out-Null
dart compile exe "$here\bin\toondio_voice.dart" -o "$out\toondio-voice.exe"
if ($LASTEXITCODE) { throw "dart compile failed ($LASTEXITCODE)" }
if (-not (Test-Path "$out\toondio-voice.exe")) { throw 'dart compile produced no toondio-voice.exe' }
foreach ($f in 'sherpa-onnx-c-api.dll', 'onnxruntime.dll', 'onnxruntime_providers_shared.dll') {
  if (-not (Test-Path "$dlls\$f")) { throw "Missing $dlls\$f (run dart pub get for sherpa_onnx_windows 1.13.8)" }
  Copy-Item "$dlls\$f" $out
}
Copy-Item "$here\LICENSE", "$here\README.md", "$here\THIRD-PARTY-NOTICES.txt" $out
Copy-Item "$here\third_party\sherpa_onnx_dart\LICENSE" "$out\LICENSE-sherpa-onnx.txt"
$zip = "$here\build\toondio-voice-engine-$version-win-x64.zip"
if (Test-Path $zip) { Remove-Item $zip }
Compress-Archive -Path $out -DestinationPath $zip
Write-Output "$zip"
Write-Output ("SHA-256 " + (Get-FileHash $zip -Algorithm SHA256).Hash.ToLower())
