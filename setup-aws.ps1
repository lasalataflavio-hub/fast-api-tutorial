# setup-aws.ps1 - Script PowerShell per setup iniziale completo dell'infrastruttura AWS
# Esegui questo script UNA SOLA VOLTA per creare tutte le risorse necessarie
#
# ESECUZIONE:
# powershell -ExecutionPolicy Bypass -File setup-aws.ps1

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
    Write-Host "Crea il file .env.local con le tue credenziali AWS" -ForegroundColor Yellow
    exit 1
}
if (-not $TABLE_NAME) { $TABLE_NAME = "fastapi-tutorial-items" }
if (-not $SECRET_NAME) { $SECRET_NAME = "fastapi-tutorial-secrets" }
if (-not $KMS_KEY_ALIAS) { $KMS_KEY_ALIAS = "alias/fastapi-tutorial-key" }
if (-not $ECR_REPO_NAME) { $ECR_REPO_NAME = "fastapi-docker-example" }
if (-not $APP_RUNNER_SERVICE_NAME) { $APP_RUNNER_SERVICE_NAME = "fastapi-tutorial-service" }
if (-not $IAM_ROLE_NAME) { $IAM_ROLE_NAME = "FastAPITutorialAppRunnerRole" }
if (-not $IAM_POLICY_NAME) { $IAM_POLICY_NAME = "FastAPITutorialAppRunnerPolicy" }
if (-not $IAM_ACCESS_ROLE_NAME) { $IAM_ACCESS_ROLE_NAME = "FastAPITutorialAppRunnerAccessRole" }

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  FastAPI AWS Tutorial - Setup Infrastruttura Completo" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "ATTENZIONE: Questo script creera risorse AWS che potrebbero generare costi." -ForegroundColor Yellow
Write-Host "Assicurati di eliminare le risorse quando non servono piu." -ForegroundColor Yellow
Write-Host ""
Write-Host "Configurazione:"
Write-Host "  Profile: $AWS_PROFILE"
Write-Host "  Region: $AWS_REGION"
Write-Host "  Account: $AWS_ACCOUNT_ID"
Write-Host ""
$confirm = Read-Host "Vuoi procedere? (yes/no)"

if ($confirm -ne "yes") {
    Write-Host "Setup annullato."
    exit 0
}

Write-Host ""

# Verifica AWS CLI
Write-Host "=== Verifica AWS CLI ===" -ForegroundColor Cyan
try {
    aws sts get-caller-identity --profile $AWS_PROFILE --output json | Out-Null
    Write-Host "OK AWS CLI configurato correttamente" -ForegroundColor Green
}
catch {
    Write-Host "ERRORE AWS CLI profile '$AWS_PROFILE' non configurato" -ForegroundColor Red
    Write-Host "Esegui: aws configure --profile $AWS_PROFILE"
    exit 1
}
Write-Host ""

# Step 1: Crea KMS Key
Write-Host "=== Step 1/9: Creazione KMS Key ===" -ForegroundColor Cyan
try {
    $KMS_KEY_ID = aws kms list-aliases --profile $AWS_PROFILE --region $AWS_REGION --query "Aliases[?AliasName=='$KMS_KEY_ALIAS'].TargetKeyId" --output text 2>$null
} catch {
    $KMS_KEY_ID = $null
}

if ([string]::IsNullOrWhiteSpace($KMS_KEY_ID)) {
    Write-Host "Creazione KMS key..."
    $KMS_KEY_ID = (aws kms create-key --description "KMS key per FastAPI Tutorial secrets" --region $AWS_REGION --profile $AWS_PROFILE --query 'KeyMetadata.KeyId' --output text)
    
    Write-Host "Creazione alias per KMS key..."
    aws kms create-alias --alias-name $KMS_KEY_ALIAS --target-key-id $KMS_KEY_ID --region $AWS_REGION --profile $AWS_PROFILE
    
    Write-Host "OK KMS Key creata: $KMS_KEY_ID" -ForegroundColor Green
}
else {
    Write-Host "AVVISO KMS Key gia esistente: $KMS_KEY_ID" -ForegroundColor Yellow
}
Write-Host ""

# Step 2: Crea Secret in Secrets Manager
Write-Host "=== Step 2/9: Creazione Secret in Secrets Manager ===" -ForegroundColor Cyan
try {
    $SECRET_EXISTS = aws secretsmanager describe-secret --secret-id $SECRET_NAME --region $AWS_REGION --profile $AWS_PROFILE --query 'Name' --output text 2>$null
} catch {
    $SECRET_EXISTS = $null
}

if ([string]::IsNullOrWhiteSpace($SECRET_EXISTS)) {
    Write-Host "Creazione secret..."
    $secretString = '{"api_key":"demo-api-key-12345","database_encryption_key":"demo-encryption-key"}'
    aws secretsmanager create-secret --name $SECRET_NAME --description "Secrets per FastAPI Tutorial" --kms-key-id $KMS_KEY_ID --secret-string $secretString --region $AWS_REGION --profile $AWS_PROFILE | Out-Null
    
    Write-Host "OK Secret creato: $SECRET_NAME" -ForegroundColor Green
}
else {
    Write-Host "AVVISO Secret gia esistente: $SECRET_NAME" -ForegroundColor Yellow
}

$SECRET_ARN = (aws secretsmanager describe-secret --secret-id $SECRET_NAME --region $AWS_REGION --profile $AWS_PROFILE --query 'ARN' --output text)
Write-Host ""

# Step 3: Crea Tabella DynamoDB
Write-Host "=== Step 3/9: Creazione Tabella DynamoDB ===" -ForegroundColor Cyan
try {
    $TABLE_EXISTS = aws dynamodb describe-table --table-name $TABLE_NAME --region $AWS_REGION --profile $AWS_PROFILE --query 'Table.TableName' --output text 2>$null
} catch {
    $TABLE_EXISTS = $null
}

if ([string]::IsNullOrWhiteSpace($TABLE_EXISTS)) {
    Write-Host "Creazione tabella DynamoDB..."
    aws dynamodb create-table --table-name $TABLE_NAME --attribute-definitions AttributeName=item_id,AttributeType=S --key-schema AttributeName=item_id,KeyType=HASH --billing-mode PAY_PER_REQUEST --region $AWS_REGION --profile $AWS_PROFILE | Out-Null
    
    Write-Host "Attesa che la tabella sia attiva..."
    aws dynamodb wait table-exists --table-name $TABLE_NAME --region $AWS_REGION --profile $AWS_PROFILE
    
    Write-Host "OK Tabella DynamoDB creata: $TABLE_NAME" -ForegroundColor Green
}
else {
    Write-Host "AVVISO Tabella DynamoDB gia esistente: $TABLE_NAME" -ForegroundColor Yellow
}
Write-Host ""

# Step 4: Crea IAM Policy
Write-Host "=== Step 4/9: Creazione IAM Policy ===" -ForegroundColor Cyan
$POLICY_ARN = "arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${IAM_POLICY_NAME}"
try {
    $POLICY_EXISTS = aws iam get-policy --policy-arn $POLICY_ARN --profile $AWS_PROFILE --query 'Policy.Arn' --output text 2>$null
} catch {
    $POLICY_EXISTS = $null
}

if ([string]::IsNullOrWhiteSpace($POLICY_EXISTS)) {
    Write-Host "Creazione IAM policy..."
    
    $policyJson = @"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:Scan",
        "dynamodb:DeleteItem",
        "dynamodb:DescribeTable"
      ],
      "Resource": "arn:aws:dynamodb:${AWS_REGION}:${AWS_ACCOUNT_ID}:table/${TABLE_NAME}"
    },
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": "${SECRET_ARN}"
    },
    {
      "Effect": "Allow",
      "Action": [
        "kms:Decrypt",
        "kms:DescribeKey"
      ],
      "Resource": "arn:aws:kms:${AWS_REGION}:${AWS_ACCOUNT_ID}:key/${KMS_KEY_ID}"
    }
  ]
}
"@
    
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText("$PWD\apprunner-policy.json", $policyJson, $utf8NoBom)
    aws iam create-policy --policy-name $IAM_POLICY_NAME --policy-document file://apprunner-policy.json --profile $AWS_PROFILE | Out-Null
    Remove-Item "apprunner-policy.json"
    
    Write-Host "OK IAM Policy creata: $IAM_POLICY_NAME" -ForegroundColor Green
}
else {
    Write-Host "AVVISO IAM Policy gia esistente: $IAM_POLICY_NAME" -ForegroundColor Yellow
}
Write-Host ""

# Step 5: Verifica/Crea IAM Role per Task
Write-Host "=== Step 5/9: Verifica IAM Role per Task ===" -ForegroundColor Cyan

# Usa il ruolo creato per i task
$IAM_ROLE_NAME = "FastAPITutorialAppRunnerTaskRole"
try {
    $ROLE_EXISTS = aws iam get-role --role-name $IAM_ROLE_NAME --profile $AWS_PROFILE --query 'Role.RoleName' --output text 2>$null
} catch {
    $ROLE_EXISTS = $null
}

if ([string]::IsNullOrWhiteSpace($ROLE_EXISTS)) {
    Write-Host "Creazione IAM role per task..."
    
    $trustPolicyJson = @'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "tasks.apprunner.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
'@
    
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText("$PWD\apprunner-trust-policy.json", $trustPolicyJson, $utf8NoBom)
    aws iam create-role --role-name $IAM_ROLE_NAME --assume-role-policy-document file://apprunner-trust-policy.json --profile $AWS_PROFILE | Out-Null
    Remove-Item "apprunner-trust-policy.json"
    
    Write-Host "Attaching policy al role..."
    aws iam attach-role-policy --role-name $IAM_ROLE_NAME --policy-arn $POLICY_ARN --profile $AWS_PROFILE
    
    Write-Host "OK IAM Role creato: $IAM_ROLE_NAME" -ForegroundColor Green
} else {
    Write-Host "OK Uso ruolo task esistente: $IAM_ROLE_NAME" -ForegroundColor Green
}

$ROLE_ARN = "arn:aws:iam::${AWS_ACCOUNT_ID}:role/${IAM_ROLE_NAME}"
Write-Host ""

# Step 5b: Usa IAM Access Role esistente per ECR
Write-Host "=== Step 5b/9: Verifica IAM Access Role per ECR ===" -ForegroundColor Cyan

# Usa il ruolo esistente AppRunnerECRAccessRole (in service-role/)
$IAM_ACCESS_ROLE_NAME = "AppRunnerECRAccessRole"
try {
    $ACCESS_ROLE_ARN = aws iam get-role --role-name $IAM_ACCESS_ROLE_NAME --profile $AWS_PROFILE --query 'Role.Arn' --output text 2>$null
    if (-not [string]::IsNullOrWhiteSpace($ACCESS_ROLE_ARN)) {
        Write-Host "OK Uso ruolo ECR esistente: $ACCESS_ROLE_ARN" -ForegroundColor Green
    }
} catch {
    Write-Host "ERRORE Ruolo AppRunnerECRAccessRole non trovato" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 6: Crea ECR Repository
Write-Host "=== Step 6/9: Creazione ECR Repository ===" -ForegroundColor Cyan
try {
    $REPO_EXISTS = aws ecr describe-repositories --repository-names $ECR_REPO_NAME --region $AWS_REGION --profile $AWS_PROFILE --query 'repositories[0].repositoryName' --output text 2>$null
} catch {
    $REPO_EXISTS = $null
}

if ([string]::IsNullOrWhiteSpace($REPO_EXISTS)) {
    Write-Host "Creazione ECR repository..."
    aws ecr create-repository --repository-name $ECR_REPO_NAME --region $AWS_REGION --profile $AWS_PROFILE | Out-Null
    
    Write-Host "OK ECR Repository creato: $ECR_REPO_NAME" -ForegroundColor Green
}
else {
    Write-Host "AVVISO ECR Repository gia esistente: $ECR_REPO_NAME" -ForegroundColor Yellow
}

$ECR_URI = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}"
Write-Host ""

# Step 7: Build e Push Docker Image
Write-Host "=== Step 7/9: Build e Push Docker Image ===" -ForegroundColor Cyan
Write-Host "Building Docker image..."
docker build -t ${ECR_REPO_NAME}:latest .

Write-Host "Login a ECR..."
$loginPassword = aws ecr get-login-password --region $AWS_REGION --profile $AWS_PROFILE
$loginPassword | docker login --username AWS --password-stdin $ECR_URI

Write-Host "Tagging e pushing image..."
docker tag ${ECR_REPO_NAME}:latest ${ECR_URI}:latest
docker push ${ECR_URI}:latest

Write-Host "OK Docker image pushata su ECR" -ForegroundColor Green
Write-Host ""

# Step 8: Crea App Runner Service
Write-Host "=== Step 8/9: Creazione App Runner Service ===" -ForegroundColor Cyan
try {
    $SERVICE_EXISTS = aws apprunner list-services --region $AWS_REGION --profile $AWS_PROFILE --query "ServiceSummaryList[?ServiceName=='${APP_RUNNER_SERVICE_NAME}'].ServiceArn" --output text 2>$null
} catch {
    $SERVICE_EXISTS = $null
}

if ([string]::IsNullOrWhiteSpace($SERVICE_EXISTS)) {
    Write-Host "Creazione App Runner service..."
    Write-Host "Questo puo richiedere alcuni minuti..."
    
    $appRunnerConfigJson = @"
{
  "ServiceName": "${APP_RUNNER_SERVICE_NAME}",
  "SourceConfiguration": {
    "ImageRepository": {
      "ImageIdentifier": "${ECR_URI}:latest",
      "ImageRepositoryType": "ECR",
      "ImageConfiguration": {
        "Port": "8000",
        "RuntimeEnvironmentVariables": {
          "AWS_REGION": "${AWS_REGION}",
          "DYNAMODB_TABLE_NAME": "${TABLE_NAME}",
          "SECRET_NAME": "${SECRET_NAME}",
          "APP_NAME": "FastAPI AWS Tutorial",
          "DEBUG": "false"
        }
      }
    },
    "AuthenticationConfiguration": {
      "AccessRoleArn": "${ACCESS_ROLE_ARN}"
    },
    "AutoDeploymentsEnabled": true
  },
  "InstanceConfiguration": {
    "InstanceRoleArn": "${ROLE_ARN}",
    "Cpu": "1 vCPU",
    "Memory": "2 GB"
  },
  "HealthCheckConfiguration": {
    "Protocol": "HTTP",
    "Path": "/health",
    "Interval": 10,
    "Timeout": 5,
    "HealthyThreshold": 1,
    "UnhealthyThreshold": 5
  }
}
"@
    
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText("$PWD\apprunner-config.json", $appRunnerConfigJson, $utf8NoBom)
    $SERVICE_ARN = (aws apprunner create-service --cli-input-json file://apprunner-config.json --region $AWS_REGION --profile $AWS_PROFILE --query 'Service.ServiceArn' --output text)
    Remove-Item "apprunner-config.json"
    
    Write-Host "Attesa che il servizio sia running..."
    aws apprunner wait service-running --service-arn $SERVICE_ARN --region $AWS_REGION --profile $AWS_PROFILE
    
    Write-Host "OK App Runner Service creato: $APP_RUNNER_SERVICE_NAME" -ForegroundColor Green
}
else {
    Write-Host "AVVISO App Runner Service gia esistente: $APP_RUNNER_SERVICE_NAME" -ForegroundColor Yellow
    $SERVICE_ARN = $SERVICE_EXISTS
}
Write-Host ""

# Ottieni URL del servizio
$SERVICE_URL = (aws apprunner describe-service --service-arn $SERVICE_ARN --region $AWS_REGION --profile $AWS_PROFILE --query 'Service.ServiceUrl' --output text)

# Riepilogo finale
Write-Host "================================================================" -ForegroundColor Green
Write-Host "           Setup Completato con Successo!" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Risorse create:"
Write-Host "  OK KMS Key: $KMS_KEY_ALIAS"
Write-Host "  OK Secret: $SECRET_NAME"
Write-Host "  OK DynamoDB Table: $TABLE_NAME"
Write-Host "  OK IAM Policy: $IAM_POLICY_NAME"
Write-Host "  OK IAM Role: $IAM_ROLE_NAME"
Write-Host "  OK ECR Repository: $ECR_REPO_NAME"
Write-Host "  OK App Runner Service: $APP_RUNNER_SERVICE_NAME"
Write-Host ""
Write-Host "Service URL: " -NoNewline
Write-Host "https://${SERVICE_URL}" -ForegroundColor Green
Write-Host ""
Write-Host "Test dell'applicazione:"
Write-Host "  curl https://${SERVICE_URL}/health"
Write-Host "  curl https://${SERVICE_URL}/"
Write-Host ""
Write-Host "Documentazione interattiva:"
Write-Host "  https://${SERVICE_URL}/docs"
Write-Host ""
Write-Host "Prossimi passi:" -ForegroundColor Yellow
Write-Host "  1. Testa l'API con i comandi sopra"
Write-Host "  2. Per deploy futuri, usa: .\deploy.ps1"
Write-Host "  3. Per eliminare tutto, usa: .\cleanup-aws.ps1"
Write-Host ""
