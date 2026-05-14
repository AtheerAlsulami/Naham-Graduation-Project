$uri = "https://yn6aki3dgl.execute-api.eu-north-1.amazonaws.com/pricing/suggest"

$categories = @("sweets", "baked", "najdi", "western")
$category = $categories[(Get-Random -Maximum $categories.Length)]
$prepTime = Get-Random -Minimum 15 -Maximum 120
$profit = Get-Random -Minimum 10 -Maximum 30

$ingredients = @(
    @{ weightGram = Get-Random -Minimum 50 -Maximum 500; costPer100Sar = [math]::Round((Get-Random -Minimum 2 -Maximum 20), 2) },
    @{ weightGram = Get-Random -Minimum 50 -Maximum 500; costPer100Sar = [math]::Round((Get-Random -Minimum 2 -Maximum 20), 2) }
)

$body = @{
    categoryId = $category
    preparationMinutes = $prepTime
    ingredients = $ingredients
    profitMode = "percentage"
    profitValue = $profit
    debugAuth = $true
} | ConvertTo-Json -Depth 5

Write-Host "--- Testing Pricing Suggestion API (PowerShell) ---"
Write-Host "Target: $uri"
Write-Host "Sending Data: $body"
Write-Host "--------------------------------------------------"

try {
    $response = Invoke-RestMethod -Uri $uri -Method Post -Body $body -ContentType "application/json"
    Write-Host "Success!" -ForegroundColor Green
    Write-Host "Suggested Price: $($response.suggestedPrice) SAR"
    Write-Host "Provider: $($response.metadata.aiProvider)"
    Write-Host "Model: $($response.metadata.aiModel)"
    Write-Host "Market Signal: $($response.metadata.marketSignal)"
    Write-Host "Reasoning:"
    Write-Host $response.aiReasoning
} catch {
    Write-Host "Error occurred:" -ForegroundColor Red
    $_.Exception.Message
    if ($_.ErrorDetails) { $_.ErrorDetails.Message }
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
