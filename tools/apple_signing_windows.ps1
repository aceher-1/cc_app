#requires -Version 7.2
<#
Create a CSR and encrypted private key on Windows, then export Apple's issued
certificate and that same private key as a password-protected P12.
All outputs must go outside this repository. Private values are never printed.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('request','export')][string]$Mode,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [string]$CertificatePath
)
$ErrorActionPreference = 'Stop'
$outputPath = [IO.Path]::GetFullPath($OutputDirectory)
$repoPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if ($outputPath.Equals($repoPath, [StringComparison]::OrdinalIgnoreCase) -or
    $outputPath.StartsWith($repoPath + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Choose an output folder outside this repository for your private signing files.'
}
[IO.Directory]::CreateDirectory($outputPath) | Out-Null
$keyPath = Join-Path $outputPath 'distribution-private.pem'
$requestPath = Join-Path $outputPath 'distribution.certSigningRequest'
$p12Path = Join-Path $outputPath 'distribution.p12'
$rsa = [Security.Cryptography.RSA]::Create()
try {
    if ($Mode -eq 'request') {
        if ((Test-Path -LiteralPath $keyPath) -or (Test-Path -LiteralPath $requestPath)) {
            throw 'Signing request files already exist. Use those files, or choose another folder; do not overwrite a private key.'
        }
        $password = Read-Host 'Choose a password to protect your local signing private key' -AsSecureString
        if ($password.Length -lt 12) { throw 'Use a password of at least 12 characters.' }
        $passwordText = [Net.NetworkCredential]::new('', $password).Password
        $rsa.KeySize = 2048
        $request = [Security.Cryptography.X509Certificates.CertificateRequest]::new(
            'CN=MSOE Dining Distribution', $rsa, [Security.Cryptography.HashAlgorithmName]::SHA256,
            [Security.Cryptography.RSASignaturePadding]::Pkcs1)
        $protection = [Security.Cryptography.PbeParameters]::new(
            [Security.Cryptography.PbeEncryptionAlgorithm]::Aes256Cbc,
            [Security.Cryptography.HashAlgorithmName]::SHA256, 200000)
        [IO.File]::WriteAllText($keyPath, $rsa.ExportEncryptedPkcs8PrivateKeyPem($passwordText, $protection))
        [IO.File]::WriteAllText($requestPath, $request.CreateSigningRequestPem())
        Write-Output "Upload only this request to Apple: $requestPath"
        Write-Output 'Keep the encrypted private key and its password. Do not upload the key to Apple or paste it into chat.'
    } else {
        if (-not $CertificatePath) { throw 'Provide -CertificatePath with the .cer downloaded from Apple.' }
        if (Test-Path -LiteralPath $p12Path) { throw 'distribution.p12 already exists; choose another folder or back it up before replacing it.' }
        $password = Read-Host 'Enter your local signing private-key password' -AsSecureString
        $passwordText = [Net.NetworkCredential]::new('', $password).Password
        $rsa.ImportFromEncryptedPem([IO.File]::ReadAllText($keyPath), $passwordText)
        $certificate = [Security.Cryptography.X509Certificates.X509Certificate2]::new([IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $CertificatePath)))
        try {
            $withKey = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::CopyWithPrivateKey($certificate, $rsa)
            try {
                $p12Password = Read-Host 'Choose a password for the P12 (save this as APPLE_DISTRIBUTION_P12_PASSWORD)' -AsSecureString
                if ($p12Password.Length -lt 12) { throw 'Use a password of at least 12 characters.' }
                $p12PasswordText = [Net.NetworkCredential]::new('', $p12Password).Password
                [IO.File]::WriteAllBytes($p12Path, $withKey.Export([Security.Cryptography.X509Certificates.X509ContentType]::Pkcs12, $p12PasswordText))
            } finally { $withKey.Dispose() }
        } finally { $certificate.Dispose() }
        Write-Output "Created password-protected signing file: $p12Path"
    }
} finally {
    $rsa.Dispose()
    $passwordText = $null
    $p12PasswordText = $null
}
