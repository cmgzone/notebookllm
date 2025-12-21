param(
  [string]$EnvPath = ".env",
  [string]$Email = "notebookllm.test+$(Get-Date -Format 'yyyyMMddHHmmss')@example.com",
  [string]$Password = "",
  [string]$Query = "Write a short paragraph about research notebooks",
  [string]$ServiceRoleKey = ""
)

function Get-EnvValue {
  param([string]$Key)
  $val = [System.Environment]::GetEnvironmentVariable($Key)
  if ($null -ne $val -and $val.Trim().Length -gt 0) { return $val }
  if (Test-Path $EnvPath) {
    $line = Select-String -Path $EnvPath -Pattern "^$Key=.*$" | Select-Object -First 1
    if ($line) { return ($line.Line -replace "^$Key=", "").Trim() }
  }
  return $null
}

$EnvPath = (Test-Path $EnvPath) ? (Resolve-Path -Path $EnvPath).Path : $EnvPath
$SUPABASE_URL = Get-EnvValue -Key "SUPABASE_URL"
$SUPABASE_ANON_KEY = Get-EnvValue -Key "SUPABASE_ANON_KEY"
$FUNCTIONS_URL = Get-EnvValue -Key "SUPABASE_FUNCTIONS_URL"

if (-not $SUPABASE_URL -or -not $SUPABASE_ANON_KEY -or -not $FUNCTIONS_URL) {
  Write-Error "Missing required .env entries: SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_FUNCTIONS_URL"; exit 1
}

if (-not $Password -or $Password.Trim().Length -eq 0) {
  $pwEnv = Get-EnvValue -Key "TEST_PASSWORD"
  if ($pwEnv -and $pwEnv.Trim().Length -gt 0) {
    $Password = $pwEnv
  } else {
    Write-Error "Missing TEST_PASSWORD (provide via env or -Password)"; exit 1
  }
}

Write-Host "Signing up (or reusing) test user: $Email"
try {
  $signupBody = @{ email = $Email; password = $Password } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "$SUPABASE_URL/auth/v1/signup" -Headers @{ apikey = $SUPABASE_ANON_KEY; "Content-Type" = "application/json" } -Body $signupBody -ErrorAction Stop | Out-Null
} catch {
  if ($_.Exception.Response.StatusCode -in 409,400) { Write-Host "User exists; continuing." } else { Write-Error "Signup failed: $($_.Exception.Message)"; exit 1 }
}

if ($ServiceRoleKey -and $ServiceRoleKey.Trim().Length -gt 0) {
  Write-Host "Admin-confirming user via service role"
  try {
    $adminBody = @{ email = $Email; password = $Password; email_confirm = $true } | ConvertTo-Json
    Invoke-RestMethod -Method Post -Uri "$SUPABASE_URL/auth/v1/admin/users" -Headers @{ apikey = $SUPABASE_ANON_KEY; Authorization = "Bearer $ServiceRoleKey"; "Content-Type" = "application/json" } -Body $adminBody -ErrorAction Stop | Out-Null
  } catch { Write-Error "Admin confirm failed: $($_.Exception.Message)"; exit 1 }
}

Write-Host "Signing in test user"
$signinBody = @{ email = $Email; password = $Password } | ConvertTo-Json
$signin = Invoke-RestMethod -Method Post -Uri "$SUPABASE_URL/auth/v1/token?grant_type=password" -Headers @{ apikey = $SUPABASE_ANON_KEY; "Content-Type" = "application/json" } -Body $signinBody -ErrorAction Stop
$accessToken = $signin.access_token
if (-not $accessToken) { Write-Error "Failed to get access token"; exit 1 }

Write-Host "Fetching user id"
$user = Invoke-RestMethod -Method Get -Uri "$SUPABASE_URL/auth/v1/user" -Headers @{ Authorization = "Bearer $accessToken"; apikey = $SUPABASE_ANON_KEY } -ErrorAction Stop
$userId = $user.id
if (-not $userId) { Write-Error "Failed to get user id"; exit 1 }

Write-Host "Invoking answer_query (plain response)"
$reqBody = @{ query = $Query; user_id = $userId } | ConvertTo-Json
$resp = Invoke-RestMethod -Method Post -Uri "$FUNCTIONS_URL/answer_query?plain=1" -Headers @{ Authorization = "Bearer $accessToken"; apikey = $SUPABASE_ANON_KEY; "Content-Type" = "application/json" } -Body $reqBody -ErrorAction Stop
Write-Host "Answer preview:"
if ($resp -and $resp.answer) {
  Write-Host ($resp.answer.Substring(0, [Math]::Min(240, $resp.answer.Length)))
} else {
  Write-Error "No answer returned"; exit 1
}
Write-Host "Citations:"
if ($resp.citations -is [System.Collections.IEnumerable]) {
  ($resp.citations | Select-Object -First 3) | ForEach-Object { Write-Host (ConvertTo-Json $_) }
} else { Write-Host "No citations." }