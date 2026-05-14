param(
    [string]$UsersApiBaseUrl = "https://1tt7d22248.execute-api.eu-north-1.amazonaws.com",
    [string]$AuthApiBaseUrl = "https://4m3cxo5831.execute-api.eu-north-1.amazonaws.com",
    [string]$UserId = "",
    [switch]$SkipCleanup
)

$ErrorActionPreference = "Stop"

function ConvertFrom-ApiJson {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RawBody
    )

    if ([string]::IsNullOrWhiteSpace($RawBody)) {
        return $null
    }

    $payload = $RawBody | ConvertFrom-Json
    if ($payload.PSObject.Properties.Name -contains "statusCode" -and
        $payload.PSObject.Properties.Name -contains "body" -and
        $payload.body -is [string]) {
        return ConvertFrom-ApiJson -RawBody $payload.body
    }
    return $payload
}

function Invoke-ApiJson {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("GET", "POST", "PUT", "DELETE")]
        [string]$Method,

        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [object]$Body = $null,

        [string]$Label = "request"
    )

    try {
        $params = @{
            Uri             = $Uri
            Method          = $Method
            UseBasicParsing = $true
        }
        if ($null -ne $Body) {
            $params.ContentType = "application/json"
            $params.Body = $Body | ConvertTo-Json -Depth 10 -Compress
        }

        $response = Invoke-WebRequest @params
        return [pscustomobject]@{
            StatusCode = [int]$response.StatusCode
            Body       = ConvertFrom-ApiJson -RawBody ([string]$response.Content)
            RawBody    = [string]$response.Content
        }
    } catch {
        $statusCode = "unknown"
        $rawBody = ""
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
            $stream = $_.Exception.Response.GetResponseStream()
            if ($stream) {
                $reader = New-Object System.IO.StreamReader($stream)
                $rawBody = $reader.ReadToEnd()
            }
        }

        throw "$Label failed ($statusCode): $rawBody"
    }
}

function Assert-ApiCondition {
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Condition,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function New-TestPdfBytes {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    return [Text.Encoding]::UTF8.GetBytes("%PDF-1.4`n% Naham cook verification smoke test: $Label`n")
}

function New-TempCookUser {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseUrl
    )

    $stamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    $email = "cook-verification-smoke-$stamp@example.com"
    $body = @{
        name     = "Cook Verification Smoke"
        email    = $email
        password = "SmokeTest12345!"
        phone    = "+966500000000"
        role     = "cook"
    }

    $response = Invoke-ApiJson `
        -Method "POST" `
        -Uri "$BaseUrl/auth/register" `
        -Body $body `
        -Label "register temp cook"

    Assert-ApiCondition `
        -Condition ($response.Body.user.id -is [string] -and $response.Body.user.id.Trim().Length -gt 0) `
        -Message "Registration response did not include user.id."

    return [pscustomobject]@{
        Id       = $response.Body.user.id
        Email    = $email
        Password = $body.password
    }
}

function Invoke-CookLogin {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseUrl,

        [Parameter(Mandatory = $true)]
        [string]$Email,

        [Parameter(Mandatory = $true)]
        [string]$Password,

        [string]$Label = "cook login"
    )

    $response = Invoke-ApiJson `
        -Method "POST" `
        -Uri "$BaseUrl/auth/login" `
        -Body @{
            email    = $Email
            password = $Password
        } `
        -Label $Label

    Assert-ApiCondition `
        -Condition ($response.Body.user.id -is [string] -and $response.Body.user.id.Trim().Length -gt 0) `
        -Message "$Label response did not include user.id."
    Assert-ApiCondition `
        -Condition ($response.Body.user.role -eq "cook") `
        -Message "$Label response did not return role=cook."

    return $response.Body.user
}

function Get-ExpectedCookRouteForStatus {
    param(
        [AllowNull()]
        [string]$CookStatus
    )

    switch ($CookStatus) {
        "approved" { return "/cook/dashboard" }
        "pending_verification" { return "/cook/waiting-approval" }
        default { return "/cook/verification-upload" }
    }
}

function Assert-CookLoginStatus {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AuthApiBaseUrl,

        [Parameter(Mandatory = $true)]
        [string]$Email,

        [Parameter(Mandatory = $true)]
        [string]$Password,

        [Parameter(Mandatory = $true)]
        [string]$ExpectedCookStatus,

        [Parameter(Mandatory = $true)]
        [string]$ExpectedRoute,

        [string]$Label = "cook login status"
    )

    $user = Invoke-CookLogin `
        -BaseUrl $AuthApiBaseUrl `
        -Email $Email `
        -Password $Password `
        -Label $Label

    Assert-ApiCondition `
        -Condition ($user.cookStatus -eq $ExpectedCookStatus) `
        -Message "$Label returned cookStatus='$($user.cookStatus)', expected '$ExpectedCookStatus'."

    $actualRoute = Get-ExpectedCookRouteForStatus -CookStatus $user.cookStatus
    Assert-ApiCondition `
        -Condition ($actualRoute -eq $ExpectedRoute) `
        -Message "$Label maps to '$actualRoute', expected '$ExpectedRoute'."

    return $user
}

function Get-VerificationUploadUrl {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseUrl,

        [Parameter(Mandatory = $true)]
        [string]$UserId,

        [Parameter(Mandatory = $true)]
        [ValidateSet("id", "health")]
        [string]$DocumentType
    )

    $fileName = "$DocumentType-smoke.pdf"
    $body = @{
        userId       = $UserId
        documentType = $DocumentType
        fileName     = $fileName
        contentType  = "application/pdf"
    }

    $response = Invoke-ApiJson `
        -Method "POST" `
        -Uri "$BaseUrl/users/upload-url" `
        -Body $body `
        -Label "get $DocumentType upload URL"

    Assert-ApiCondition `
        -Condition ($response.Body.uploadUrl -is [string] -and $response.Body.uploadUrl.StartsWith("https://")) `
        -Message "$DocumentType upload URL is missing or invalid."
    Assert-ApiCondition `
        -Condition ($response.Body.fileUrl -is [string] -and $response.Body.fileUrl.StartsWith("https://")) `
        -Message "$DocumentType file URL is missing or invalid."
    Assert-ApiCondition `
        -Condition ($response.Body.key -is [string] -and $response.Body.key.Contains("/verification/$DocumentType/")) `
        -Message "$DocumentType object key does not contain the expected verification path."

    return $response.Body
}

function Send-TestPdfToS3 {
    param(
        [Parameter(Mandatory = $true)]
        [string]$UploadUrl,

        [Parameter(Mandatory = $true)]
        [byte[]]$Bytes,

        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    try {
        $response = Invoke-WebRequest `
            -Uri $UploadUrl `
            -Method PUT `
            -ContentType "application/pdf" `
            -Body $Bytes `
            -UseBasicParsing

        Assert-ApiCondition `
            -Condition ([int]$response.StatusCode -ge 200 -and [int]$response.StatusCode -lt 300) `
            -Message "$Label S3 upload failed with status $($response.StatusCode)."
    } catch {
        throw "$Label S3 upload failed: $($_.Exception.Message)"
    }
}

function Update-CookVerificationUrls {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseUrl,

        [Parameter(Mandatory = $true)]
        [string]$UserId,

        [Parameter(Mandatory = $true)]
        [string]$IdFileUrl,

        [Parameter(Mandatory = $true)]
        [string]$HealthFileUrl
    )

    $encodedUserId = [Uri]::EscapeDataString($UserId)
    $body = @{
        cookStatus            = "pending_verification"
        verificationIdUrl     = $IdFileUrl
        verificationHealthUrl = $HealthFileUrl
    }

    $response = Invoke-ApiJson `
        -Method "PUT" `
        -Uri "$BaseUrl/users/$encodedUserId" `
        -Body $body `
        -Label "update cook verification URLs"

    Assert-ApiCondition `
        -Condition ($response.Body.user.verificationIdUrl -eq $IdFileUrl) `
        -Message "Updated user response is missing verificationIdUrl."
    Assert-ApiCondition `
        -Condition ($response.Body.user.verificationHealthUrl -eq $HealthFileUrl) `
        -Message "Updated user response is missing verificationHealthUrl."
    Assert-ApiCondition `
        -Condition (@($response.Body.user.documents).Count -ge 2) `
        -Message "Updated user response did not include both verification documents."

    return $response.Body.user
}

function Assert-UserListContainsVerificationDocs {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseUrl,

        [Parameter(Mandatory = $true)]
        [string]$UserId,

        [Parameter(Mandatory = $true)]
        [string]$IdFileUrl,

        [Parameter(Mandatory = $true)]
        [string]$HealthFileUrl
    )

    $encodedUserId = [Uri]::EscapeDataString($UserId)
    $response = Invoke-ApiJson `
        -Method "GET" `
        -Uri "$BaseUrl/users?id=$encodedUserId" `
        -Label "load user from users list"

    Assert-ApiCondition `
        -Condition ($response.Body.user.id -eq $UserId) `
        -Message "GET /users?id=... did not return the expected user."
    Assert-ApiCondition `
        -Condition ($response.Body.user.verificationIdUrl -eq $IdFileUrl) `
        -Message "GET /users response is missing verificationIdUrl."
    Assert-ApiCondition `
        -Condition ($response.Body.user.verificationHealthUrl -eq $HealthFileUrl) `
        -Message "GET /users response is missing verificationHealthUrl."
    Assert-ApiCondition `
        -Condition (@($response.Body.user.documents).Count -ge 2) `
        -Message "GET /users response did not include both verification documents."

    return $response.Body.user
}

function Update-CookStatusForTest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseUrl,

        [Parameter(Mandatory = $true)]
        [string]$UserId,

        [Parameter(Mandatory = $true)]
        [ValidateSet("approved", "pending_verification", "rejected")]
        [string]$CookStatus
    )

    $encodedUserId = [Uri]::EscapeDataString($UserId)
    $response = Invoke-ApiJson `
        -Method "PUT" `
        -Uri "$BaseUrl/users/$encodedUserId" `
        -Body @{ cookStatus = $CookStatus } `
        -Label "set cookStatus=$CookStatus"

    Assert-ApiCondition `
        -Condition ($response.Body.user.cookStatus -eq $CookStatus) `
        -Message "Status update returned cookStatus='$($response.Body.user.cookStatus)', expected '$CookStatus'."

    return $response.Body.user
}

function Test-CookVerificationStatusCycle {
    param(
        [Parameter(Mandatory = $true)]
        [string]$UsersApiBaseUrl,

        [Parameter(Mandatory = $true)]
        [string]$AuthApiBaseUrl,

        [Parameter(Mandatory = $true)]
        [string]$UserId,

        [Parameter(Mandatory = $true)]
        [string]$Email,

        [Parameter(Mandatory = $true)]
        [string]$Password
    )

    Write-Host "6. Verifying login sees pending verification status..."
    Assert-CookLoginStatus `
        -AuthApiBaseUrl $AuthApiBaseUrl `
        -Email $Email `
        -Password $Password `
        -ExpectedCookStatus "pending_verification" `
        -ExpectedRoute "/cook/waiting-approval" `
        -Label "login after verification upload" | Out-Null

    Write-Host "7. Rejecting temp cook and verifying app route should return to upload..."
    Update-CookStatusForTest `
        -BaseUrl $UsersApiBaseUrl `
        -UserId $UserId `
        -CookStatus "rejected" | Out-Null
    Assert-CookLoginStatus `
        -AuthApiBaseUrl $AuthApiBaseUrl `
        -Email $Email `
        -Password $Password `
        -ExpectedCookStatus "rejected" `
        -ExpectedRoute "/cook/verification-upload" `
        -Label "login after admin rejection" | Out-Null

    Write-Host "8. Approving temp cook and verifying app route should open dashboard..."
    Update-CookStatusForTest `
        -BaseUrl $UsersApiBaseUrl `
        -UserId $UserId `
        -CookStatus "approved" | Out-Null
    Assert-CookLoginStatus `
        -AuthApiBaseUrl $AuthApiBaseUrl `
        -Email $Email `
        -Password $Password `
        -ExpectedCookStatus "approved" `
        -ExpectedRoute "/cook/dashboard" `
        -Label "login after admin approval" | Out-Null
}

function Remove-TestUser {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseUrl,

        [Parameter(Mandatory = $true)]
        [string]$UserId
    )

    $encodedUserId = [Uri]::EscapeDataString($UserId)
    try {
        Invoke-ApiJson `
            -Method "DELETE" `
            -Uri "$BaseUrl/users/$encodedUserId" `
            -Label "delete temp cook" | Out-Null
        Write-Host "Cleanup: deleted temp user $UserId" -ForegroundColor DarkGray
    } catch {
        Write-Host "Cleanup warning: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

function Test-CookVerificationFlow {
    param(
        [Parameter(Mandatory = $true)]
        [string]$UsersApiBaseUrl,

        [Parameter(Mandatory = $true)]
        [string]$AuthApiBaseUrl,

        [string]$ExistingUserId = "",

        [switch]$SkipCleanup
    )

    $createdTempUser = $false
    $testUserId = $ExistingUserId.Trim()
    $testEmail = ""
    $testPassword = ""

    if (-not $testUserId) {
        Write-Host "1. Registering temporary cook user..."
        $tempUser = New-TempCookUser -BaseUrl $AuthApiBaseUrl
        $testUserId = $tempUser.Id
        $testEmail = $tempUser.Email
        $testPassword = $tempUser.Password
        $createdTempUser = $true
        Write-Host "   Temp user: $testUserId"
    } else {
        Write-Host "1. Using existing cook user: $testUserId"
    }

    try {
        Write-Host "2. Requesting verification upload URLs..."
        $idUpload = Get-VerificationUploadUrl `
            -BaseUrl $UsersApiBaseUrl `
            -UserId $testUserId `
            -DocumentType "id"
        $healthUpload = Get-VerificationUploadUrl `
            -BaseUrl $UsersApiBaseUrl `
            -UserId $testUserId `
            -DocumentType "health"

        Write-Host "3. Uploading small PDF probes to S3..."
        Send-TestPdfToS3 `
            -UploadUrl $idUpload.uploadUrl `
            -Bytes (New-TestPdfBytes -Label "id") `
            -Label "identity document"
        Send-TestPdfToS3 `
            -UploadUrl $healthUpload.uploadUrl `
            -Bytes (New-TestPdfBytes -Label "health") `
            -Label "health document"

        Write-Host "4. Saving verification URLs on the user record..."
        $updatedUser = Update-CookVerificationUrls `
            -BaseUrl $UsersApiBaseUrl `
            -UserId $testUserId `
            -IdFileUrl $idUpload.fileUrl `
            -HealthFileUrl $healthUpload.fileUrl

        Write-Host "5. Verifying admin/list API returns documents..."
        $listedUser = Assert-UserListContainsVerificationDocs `
            -BaseUrl $UsersApiBaseUrl `
            -UserId $testUserId `
            -IdFileUrl $idUpload.fileUrl `
            -HealthFileUrl $healthUpload.fileUrl

        Write-Host "Success: cook verification upload/save/list flow is working." -ForegroundColor Green
        Write-Host "User: $($listedUser.id)"
        Write-Host "Documents: $(@($listedUser.documents).Count)"
        Write-Host "ID URL: $($updatedUser.verificationIdUrl)"
        Write-Host "Health URL: $($updatedUser.verificationHealthUrl)"

        if ($createdTempUser) {
            Test-CookVerificationStatusCycle `
                -UsersApiBaseUrl $UsersApiBaseUrl `
                -AuthApiBaseUrl $AuthApiBaseUrl `
                -UserId $testUserId `
                -Email $testEmail `
                -Password $testPassword
            Write-Host "Success: full cook verification approval/rejection cycle is working." -ForegroundColor Green
        } else {
            Write-Host "Skipped status cycle because -UserId was provided for an existing user." -ForegroundColor Yellow
        }
    } finally {
        if ($createdTempUser -and -not $SkipCleanup) {
            Remove-TestUser -BaseUrl $UsersApiBaseUrl -UserId $testUserId
        }
    }
}

Write-Host "--- Testing Cook Verification Flow ---"
Write-Host "Users API: $UsersApiBaseUrl"
Write-Host "Auth API:  $AuthApiBaseUrl"
Write-Host "--------------------------------------"

Test-CookVerificationFlow `
    -UsersApiBaseUrl $UsersApiBaseUrl `
    -AuthApiBaseUrl $AuthApiBaseUrl `
    -ExistingUserId $UserId `
    -SkipCleanup:$SkipCleanup
