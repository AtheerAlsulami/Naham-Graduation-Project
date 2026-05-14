$ErrorActionPreference = "Stop"

$model = "llama-3.1-8b-instant"
$uri = "https://api.groq.com/openai/v1/chat/completions"
$key = (Read-Host "Paste Groq API key").Trim()

if (-not $key) {
    throw "GROQ_API_KEY is empty."
}

$hash = [BitConverter]::ToString(
    [Security.Cryptography.SHA256]::Create().ComputeHash(
        [Text.Encoding]::UTF8.GetBytes($key)
    )
).Replace("-", "").ToLower()

Write-Host "--- Direct Groq API Test ---"
Write-Host "Model: $model"
Write-Host "Key length: $($key.Length)"
Write-Host "Key hash: $($hash.Substring(0, 12))"
Write-Host "Key starts with gsk_: $($key.StartsWith('gsk_'))"
Write-Host "----------------------------"

$body = @{
    model = $model
    messages = @(
        @{
            role = "user"
            content = "Reply with OK only."
        }
    )
    temperature = 0.1
    max_completion_tokens = 10
} | ConvertTo-Json -Depth 5

$headers = @{
    Authorization = "Bearer $key"
    "Content-Type" = "application/json"
}

try {
    $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body
    Write-Host "Success!" -ForegroundColor Green
    Write-Host "Response model: $($response.model)"
    Write-Host "Assistant reply: $($response.choices[0].message.content)"
} catch {
    Write-Host "Groq direct test failed:" -ForegroundColor Red
    $_.Exception.Message
    if ($_.ErrorDetails) {
        $_.ErrorDetails.Message
    }
    if ($_.Exception.Response) {
        try {
            $stream = $_.Exception.Response.GetResponseStream()
            if ($stream) {
                $reader = New-Object System.IO.StreamReader($stream)
                $rawBody = $reader.ReadToEnd()
                if ($rawBody) {
                    Write-Host "Raw response body:"
                    Write-Host $rawBody
                }
            }
        } catch {
            Write-Host "Could not read raw response body."
        }
    }
}
