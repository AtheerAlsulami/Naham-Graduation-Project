$ErrorActionPreference = "Stop"

$key = (Read-Host "Paste Groq API key").Trim()
if (-not $key) {
    throw "GROQ_API_KEY is empty."
}

$hash = [BitConverter]::ToString(
    [Security.Cryptography.SHA256]::Create().ComputeHash(
        [Text.Encoding]::UTF8.GetBytes($key)
    )
).Replace("-", "").ToLower()

Write-Host "--- Local Lambda Pricing Test ---"
Write-Host "Key length: $($key.Length)"
Write-Host "Key hash: $($hash.Substring(0, 12))"
Write-Host "Key starts with gsk_: $($key.StartsWith('gsk_'))"
Write-Host "-------------------------------"

$env:AI_PROVIDER = "groq"
$env:GROQ_API_KEY = $key
$env:GROQ_MODEL = "llama-3.1-8b-instant"

$nodeScript = @'
const fn = require("./backend/aws/pricingSuggest");

const event = {
  body: JSON.stringify({
    debugAuth: true,
    categoryId: "baked",
    preparationMinutes: 33,
    ingredients: [
      { weightGram: 394, costPer100Sar: 4 },
      { weightGram: 300, costPer100Sar: 4 }
    ],
    profitMode: "percentage",
    profitValue: 21
  })
};

fn.handler(event)
  .then((result) => {
    console.log("Status:", result.statusCode);
    console.log(result.body);
  })
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
'@

$nodeScript | node -
