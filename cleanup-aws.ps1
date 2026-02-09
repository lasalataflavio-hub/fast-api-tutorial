# cleanup-aws.ps1 - Script per eliminare tutte le risorse AWS create
# ATTENZIONE: Questo eliminera' TUTTE le risorse create da setup-aws.ps1
#
# ESECUZIONE:
# powershell -ExecutionPolicy Bypass -File cleanup-aws.ps1

$ErrorActionPreference = "Continue"

# Carica variabili da .env.local se esiste
if (Test-Path .env.local) {
    Write-Host "Caricamento configurazione da .env.local..." -ForegroundColor Cyan
    Get-Content .env.local | ForEach-Object {
        if ($_ -match '^([^#][^=]+)=(.+)$') {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim() -replace '\s*#.*$', ''
            Set-Variable -Name $name -Value $value -Scope Script
        }
    }
    Write-Host ""
}

# Variabili (usa .env.local o default)
if (-not $AWS_PROFILE) { $AWS_PROFILE = "default" }
if (-not $AWS_REGION) { $AWS_REGION = "eu-west-1" }
if (-not $AWS_ACCOUNT_ID) { 
    Write-Host "ERRORE: AWS_ACCOUNT_ID non trovato in .env.local" -ForegroundColor Red
    exit 1
}
if (-not $TABLE_NAME) { $TABLE_NAME = "fastapi-tutorial-items" }
if (-not $SECRET_NAME) { $SECRET_NAME = "fastapi-tutorial-secrets" }
if (-not $KMS_KEY_ALIAS) { $KMS_KEY_ALIAS = "alias/fastapi-tutorial-key" }
if (-not $ECR_REPO_NAME) { $ECR_REPO_NAME = "fastapi-docker-example" }
if (-not $APP_RUNNER_SERVICE_NAME) { $APP_RUNNER_SERVICE_NAME = "fastapi-tutorial-service" }
if (-not $IAM_ROLE_NAME) { $IAM_ROLE_NAME = "FastAPITutorialAppRunnerTaskRole" }
if (-not $IAM_POLICY_NAME) { $IAM_POLICY_NAME = "FastAPITutorialAppRunnerPolicy" }
if (-not $IAM_ACCESS_ROLE_NAME) { $IAM_ACCESS_ROLE_NAME = "FastAPITutorialAppRunnerAccessRole" }

Write-Host "================================================================" -ForegroundColor Red
Write-Host "  ATTENZIONE: Eliminazione Risorse AWS" -ForegroundColor Red
Write-Host "================================================================" -ForegroundColor Red
Write-Host ""
Write-Host "Questo script eliminera' TUTTE le seguenti risorse:" -ForegroundColor Yellow
Write-Host "  - App Runner Service: $APP_RUNNER_SERVICE_NAME"
Write-Host "  - ECR Repository: $ECR_REPO_NAME (e tutte le immagini)"
Write-Host "  - DynamoDB Table: $TABLE_NAME (e tutti i dati)"
Write-Host "  - Secret: $SECRET_NAME"
Write-Host "  - KMS Key: $KMS_KEY_ALIAS (scheduled deletion)"
Write-Host "  - IAM Role: $IAM_ROLE_NAME"
Write-Host "  - IAM Policy: $IAM_POLICY_NAME"
Write-Host "  - IAM Access Role: $IAM_ACCESS_ROLE_NAME"
Write-Host ""
Write-Host "ATTENZIONE: Questa operazione e' IRREVERSIBILE!" -ForegroundColor Red
Write-Host ""
$confirm = Read-Host "Sei ASSOLUTAMENTE sicuro? Digita 'DELETE' per confermare"

if ($confirm -ne "DELETE") {
    Write-Host "Operazione annullata." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Inizio eliminazione risorse..." -ForegroundColor Cyan
Write-Host ""

# 1. Elimina App Runner Service
Write-Host "[1/8] Eliminazione App Runner Service..." -ForegroundColor Yellow
try {
    $SERVICE_ARN = aws apprunner list-services --region $AWS_REGION --profile $AWS_PROFILE --query "ServiceSummaryList[?ServiceName=='${APP_RUNNER_SERVICE_NAME}'].ServiceArn" --output text 2>$null
    
    if ($SERVICE_ARN -and $SERVICE_ARN -ne "") {
        aws apprunner delete-service --service-arn $SERVICE_ARN --region $AWS_REGION --profile $AWS_PROFILE | Out-Null
        Write-Host "  OK App Runner Service eliminato" -ForegroundColor Green
    } else {
        Write-Host "  AVVISO App Runner Service non trovato" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  AVVISO Errore durante eliminazione App Runner Service" -ForegroundColor Yellow
}

# 2. Elimina ECR Repository
Write-Host "[2/8] Eliminazione ECR Repository..." -ForegroundColor Yellow
try {
    $REPO_EXISTS = aws ecr describe-repositories --repository-names $ECR_REPO_NAME --region $AWS_REGION --profile $AWS_PROFILE --query 'repositories[0].repositoryName' --output text 2>$null
    
    if ($REPO_EXISTS -and $REPO_EXISTS -ne "") {
        aws ecr delete-repository --repository-name $ECR_REPO_NAME --region $AWS_REGION --profile $AWS_PROFILE --force | Out-Null
        Write-Host "  OK ECR Repository eliminato" -ForegroundColor Green
    } else {
        Write-Host "  AVVISO ECR Repository non trovato" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  AVVISO Errore durante eliminazione ECR Repository" -ForegroundColor Yellow
}

# 3. Elimina DynamoDB Table
Write-Host "[3/8] Eliminazione DynamoDB Table..." -ForegroundColor Yellow
try {
    $TABLE_EXISTS = aws dynamodb describe-table --table-name $TABLE_NAME --region $AWS_REGION --profile $AWS_PROFILE --query 'Table.TableName' --output text 2>$null
    
    if ($TABLE_EXISTS -and $TABLE_EXISTS -ne "") {
        aws dynamodb delete-table --table-name $TABLE_NAME --region $AWS_REGION --profile $AWS_PROFILE | Out-Null
        Write-Host "  OK DynamoDB Table eliminata" -ForegroundColor Green
    } else {
        Write-Host "  AVVISO DynamoDB Table non trovata" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  AVVISO Errore durante eliminazione DynamoDB Table" -ForegroundColor Yellow
}

# 4. Elimina Secret
Write-Host "[4/8] Eliminazione Secret..." -ForegroundColor Yellow
try {
    $SECRET_EXISTS = aws secretsmanager describe-secret --secret-id $SECRET_NAME --region $AWS_REGION --profile $AWS_PROFILE --query 'Name' --output text 2>$null
    
    if ($SECRET_EXISTS -and $SECRET_EXISTS -ne "") {
        aws secretsmanager delete-secret --secret-id $SECRET_NAME --force-delete-without-recovery --region $AWS_REGION --profile $AWS_PROFILE | Out-Null
        Write-Host "  OK Secret eliminato" -ForegroundColor Green
    } else {
        Write-Host "  AVVISO Secret non trovato" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  AVVISO Errore durante eliminazione Secret" -ForegroundColor Yellow
}

# 5. Schedule KMS Key deletion
Write-Host "[5/8] Schedule KMS Key deletion..." -ForegroundColor Yellow
try {
    $KMS_KEY_ID = aws kms list-aliases --profile $AWS_PROFILE --region $AWS_REGION --query "Aliases[?AliasName=='${KMS_KEY_ALIAS}'].TargetKeyId" --output text 2>$null
    
    if ($KMS_KEY_ID -and $KMS_KEY_ID -ne "") {
        # Elimina alias
        aws kms delete-alias --alias-name $KMS_KEY_ALIAS --region $AWS_REGION --profile $AWS_PROFILE 2>$null
        
        # Schedule key deletion (minimo 7 giorni)
        aws kms schedule-key-deletion --key-id $KMS_KEY_ID --pending-window-in-days 7 --region $AWS_REGION --profile $AWS_PROFILE | Out-Null
        Write-Host "  OK KMS Key scheduled for deletion (7 giorni)" -ForegroundColor Green
    } else {
        Write-Host "  AVVISO KMS Key non trovata" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  AVVISO Errore durante schedule KMS Key deletion" -ForegroundColor Yellow
}

# 6. Elimina IAM Role
Write-Host "[6/8] Eliminazione IAM Role..." -ForegroundColor Yellow
try {
    $ROLE_EXISTS = aws iam get-role --role-name $IAM_ROLE_NAME --profile $AWS_PROFILE --query 'Role.RoleName' --output text 2>$null
    
    if ($ROLE_EXISTS -and $ROLE_EXISTS -ne "") {
        # Detach policy
        $POLICY_ARN = "arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${IAM_POLICY_NAME}"
        aws iam detach-role-policy --role-name $IAM_ROLE_NAME --policy-arn $POLICY_ARN --profile $AWS_PROFILE 2>$null
        
        # Delete role
        aws iam delete-role --role-name $IAM_ROLE_NAME --profile $AWS_PROFILE | Out-Null
        Write-Host "  OK IAM Role eliminato" -ForegroundColor Green
    } else {
        Write-Host "  AVVISO IAM Role non trovato" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  AVVISO Errore durante eliminazione IAM Role" -ForegroundColor Yellow
}

# 7. Elimina IAM Policy
Write-Host "[7/8] Eliminazione IAM Policy..." -ForegroundColor Yellow
try {
    $POLICY_ARN = "arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${IAM_POLICY_NAME}"
    $POLICY_EXISTS = aws iam get-policy --policy-arn $POLICY_ARN --profile $AWS_PROFILE --query 'Policy.Arn' --output text 2>$null
    
    if ($POLICY_EXISTS -and $POLICY_EXISTS -ne "") {
        # Verifica se e' ancora attaccata a qualche ruolo
        $ATTACHED_ROLES = aws iam list-entities-for-policy --policy-arn $POLICY_ARN --profile $AWS_PROFILE --query 'PolicyRoles[].RoleName' --output text 2>$null
        
        if ($ATTACHED_ROLES) {
            # Detach da tutti i ruoli
            $ATTACHED_ROLES -split '\s+' | ForEach-Object {
                if ($_ -ne "") {
                    Write-Host "  Detaching policy da ruolo: $_" -ForegroundColor Gray
                    aws iam detach-role-policy --role-name $_ --policy-arn $POLICY_ARN --profile $AWS_PROFILE 2>$null
                }
            }
        }
        
        aws iam delete-policy --policy-arn $POLICY_ARN --profile $AWS_PROFILE | Out-Null
        Write-Host "  OK IAM Policy eliminata" -ForegroundColor Green
    } else {
        Write-Host "  AVVISO IAM Policy non trovata" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  AVVISO Errore durante eliminazione IAM Policy" -ForegroundColor Yellow
}

# 8. Elimina IAM Access Role per ECR
Write-Host "[8/8] Eliminazione IAM Access Role..." -ForegroundColor Yellow
try {
    $ACCESS_ROLE_EXISTS = aws iam get-role --role-name $IAM_ACCESS_ROLE_NAME --profile $AWS_PROFILE --query 'Role.RoleName' --output text 2>$null
    
    if ($ACCESS_ROLE_EXISTS -and $ACCESS_ROLE_EXISTS -ne "") {
        # Detach managed policy
        aws iam detach-role-policy --role-name $IAM_ACCESS_ROLE_NAME --policy-arn arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess --profile $AWS_PROFILE 2>$null
        
        # Delete role
        aws iam delete-role --role-name $IAM_ACCESS_ROLE_NAME --profile $AWS_PROFILE | Out-Null
        Write-Host "  OK IAM Access Role eliminato" -ForegroundColor Green
    } else {
        Write-Host "  AVVISO IAM Access Role non trovato" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  AVVISO Errore durante eliminazione IAM Access Role" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "           Cleanup Completato!" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Tutte le risorse sono state eliminate." -ForegroundColor Green
Write-Host ""
Write-Host "Nota: La KMS Key sara' eliminata definitivamente tra 7 giorni." -ForegroundColor Yellow
Write-Host "      Puoi annullare la deletion con:" -ForegroundColor Yellow
Write-Host "      aws kms cancel-key-deletion --key-id <key-id> --profile $AWS_PROFILE" -ForegroundColor Gray
Write-Host ""