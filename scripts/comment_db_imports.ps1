# PowerShell script to comment out neon_database_service imports

$files = @(
    "lib\main.dart",
    "lib\core\auth\custom_auth_service.dart",
    "lib\core\backend\neon_functions_service.dart",
    "lib\core\media\media_service.dart",
    "lib\core\security\credentials_service.dart",
    "lib\core\security\global_credentials_service.dart",
    "lib\features\admin\quick_deploy_keys.dart",
    "lib\features\admin\services\ai_model_service.dart",
    "lib\features\onboarding\onboarding_screen.dart",
    "lib\features\settings\privacy_policy_screen.dart",
    "lib\features\sources\enhanced_sources_screen.dart",
    "lib\features\sources\source_detail_screen.dart",
    "lib\features\studio\artifact_provider.dart",
    "lib\features\subscription\providers\subscription_provider.dart",
    "lib\features\subscription\screens\subscription_screen.dart",
    "lib\features\subscription\services\paypal_service.dart",
    "lib\features\subscription\services\stripe_service.dart",
    "lib\features\subscription\services\subscription_service.dart",
    "lib\features\tags\tag_provider.dart"
)

foreach ($file in $files) {
    $fullPath = "c:\Users\Admin\Documents\project\NOTBOOK LLM\$file"
    if (Test-Path $fullPath) {
        Write-Host "Processing: $file"
        $content = Get-Content $fullPath -Raw
        
        # Comment out the import
        $content = $content -replace "import.*neon_database_service\.dart';", "// import neon_database_service.dart'; // REMOVED: Using API now"
        
        # Comment out provider usages
        $content = $content -replace "ref\.read\(neonDatabaseServiceProvider\)", "// ref.read(neonDatabaseServiceProvider) // REMOVED: Using API now"
        
        Set-Content -Path $fullPath -Value $content
        Write-Host "✅ Updated: $file"
    }
    else {
        Write-Host "⚠️ Not found: $file"
    }
}

Write-Host "`n✅ All files updated!"
