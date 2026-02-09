#!/bin/bash
# setup-aws.sh - Script per setup iniziale completo dell'infrastruttura AWS
# Esegui questo script UNA SOLA VOLTA per creare tutte le risorse necessarie

set -e

# Carica variabili da .env.local se esiste
if [ -f .env.local ]; then
    echo "Caricamento configurazione da .env.local..."
    export $(grep -v '^#' .env.local | xargs)
    echo ""
fi

# Colori
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variabili (usa .env.local o default)
AWS_PROFILE=${AWS_PROFILE:-default}
AWS_REGION=${AWS_REGION:-eu-west-1}
if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo -e "${RED}ERRORE: AWS_ACCOUNT_ID non trovato in .env.local${NC}"
    echo -e "${YELLOW}Crea il file .env.local con le tue credenziali AWS${NC}"
    exit 1
fi
TABLE_NAME=${TABLE_NAME:-fastapi-tutorial-items}
SECRET_NAME=${SECRET_NAME:-fastapi-tutorial-secrets}
KMS_KEY_ALIAS=${KMS_KEY_ALIAS:-alias/fastapi-tutorial-key}
ECR_REPO_NAME=${ECR_REPO_NAME:-fastapi-docker-example}
APP_RUNNER_SERVICE_NAME=${APP_RUNNER_SERVICE_NAME:-fastapi-tutorial-service}
IAM_ROLE_NAME=${IAM_ROLE_NAME:-FastAPITutorialAppRunnerRole}
IAM_POLICY_NAME=${IAM_POLICY_NAME:-FastAPITutorialAppRunnerPolicy}
IAM_ACCESS_ROLE_NAME=${IAM_ACCESS_ROLE_NAME:-FastAPITutorialAppRunnerAccessRole}

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  FastAPI AWS Tutorial - Setup Infrastruttura Completo    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}⚠️  ATTENZIONE: Questo script creerà risorse AWS che potrebbero generare costi.${NC}"
echo -e "${YELLOW}   Assicurati di eliminare le risorse quando non servono più.${NC}"
echo ""
echo "Configurazione:"
echo "  Profile: ${AWS_PROFILE}"
echo "  Region: ${AWS_REGION}"
echo "  Account: ${AWS_ACCOUNT_ID}"
echo ""
read -p "Vuoi procedere? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Setup annullato."
    exit 0
fi

echo ""

# Verifica AWS CLI
echo -e "${BLUE}=== Verifica AWS CLI ===${NC}"
if ! aws sts get-caller-identity --profile $AWS_PROFILE &> /dev/null; then
    echo -e "${RED}❌ AWS CLI profile '$AWS_PROFILE' non configurato${NC}"
    echo "Esegui: aws configure --profile $AWS_PROFILE"
    exit 1
fi
echo -e "${GREEN}✓${NC} AWS CLI configurato correttamente"
echo ""

# Step 1: Crea KMS Key
echo -e "${BLUE}=== Step 1/8: Creazione KMS Key ===${NC}"
KMS_KEY_ID=$(aws kms list-aliases --profile $AWS_PROFILE --region $AWS_REGION \
  --query "Aliases[?AliasName=='${KMS_KEY_ALIAS}'].TargetKeyId" --output text 2>/dev/null || echo "")

if [ -z "$KMS_KEY_ID" ]; then
    echo "Creazione KMS key..."
    KMS_KEY_ID=$(aws kms create-key \
      --description "KMS key per FastAPI Tutorial secrets" \
      --region $AWS_REGION \
      --profile $AWS_PROFILE \
      --query 'KeyMetadata.KeyId' \
      --output text)
    
    echo "Creazione alias per KMS key..."
    aws kms create-alias \
      --alias-name $KMS_KEY_ALIAS \
      --target-key-id $KMS_KEY_ID \
      --region $AWS_REGION \
      --profile $AWS_PROFILE
    
    echo -e "${GREEN}✓${NC} KMS Key creata: $KMS_KEY_ID"
else
    echo -e "${YELLOW}⚠${NC}  KMS Key già esistente: $KMS_KEY_ID"
fi
echo ""

# Step 2: Crea Secret in Secrets Manager
echo -e "${BLUE}=== Step 2/8: Creazione Secret in Secrets Manager ===${NC}"
SECRET_EXISTS=$(aws secretsmanager describe-secret \
  --secret-id $SECRET_NAME \
  --region $AWS_REGION \
  --profile $AWS_PROFILE \
  --query 'Name' --output text 2>/dev/null || echo "")

if [ -z "$SECRET_EXISTS" ]; then
    echo "Creazione secret..."
    aws secretsmanager create-secret \
      --name $SECRET_NAME \
      --description "Secrets per FastAPI Tutorial" \
      --kms-key-id $KMS_KEY_ID \
      --secret-string '{"api_key":"demo-api-key-12345","database_encryption_key":"demo-encryption-key"}' \
      --region $AWS_REGION \
      --profile $AWS_PROFILE > /dev/null
    
    echo -e "${GREEN}✓${NC} Secret creato: $SECRET_NAME"
else
    echo -e "${YELLOW}⚠${NC}  Secret già esistente: $SECRET_NAME"
fi

SECRET_ARN=$(aws secretsmanager describe-secret \
  --secret-id $SECRET_NAME \
  --region $AWS_REGION \
  --profile $AWS_PROFILE \
  --query 'ARN' \
  --output text)
echo ""

# Step 3: Crea Tabella DynamoDB
echo -e "${BLUE}=== Step 3/8: Creazione Tabella DynamoDB ===${NC}"
TABLE_EXISTS=$(aws dynamodb describe-table \
  --table-name $TABLE_NAME \
  --region $AWS_REGION \
  --profile $AWS_PROFILE \
  --query 'Table.TableName' --output text 2>/dev/null || echo "")

if [ -z "$TABLE_EXISTS" ]; then
    echo "Creazione tabella DynamoDB..."
    aws dynamodb create-table \
      --table-name $TABLE_NAME \
      --attribute-definitions AttributeName=item_id,AttributeType=S \
      --key-schema AttributeName=item_id,KeyType=HASH \
      --billing-mode PAY_PER_REQUEST \
      --region $AWS_REGION \
      --profile $AWS_PROFILE > /dev/null
    
    echo "Attesa che la tabella sia attiva..."
    aws dynamodb wait table-exists \
      --table-name $TABLE_NAME \
      --region $AWS_REGION \
      --profile $AWS_PROFILE
    
    echo -e "${GREEN}✓${NC} Tabella DynamoDB creata: $TABLE_NAME"
else
    echo -e "${YELLOW}⚠${NC}  Tabella DynamoDB già esistente: $TABLE_NAME"
fi
echo ""

# Step 4: Crea IAM Policy
echo -e "${BLUE}=== Step 4/8: Creazione IAM Policy ===${NC}"
POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${IAM_POLICY_NAME}"
POLICY_EXISTS=$(aws iam get-policy --policy-arn $POLICY_ARN --profile $AWS_PROFILE --query 'Policy.Arn' --output text 2>/dev/null || echo "")

if [ -z "$POLICY_EXISTS" ]; then
    echo "Creazione IAM policy..."
    
    # Crea file policy temporaneo
    cat > /tmp/apprunner-policy.json << EOF
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
EOF
    
    aws iam create-policy \
      --policy-name $IAM_POLICY_NAME \
      --policy-document file:///tmp/apprunner-policy.json \
      --profile $AWS_PROFILE > /dev/null
    
    rm /tmp/apprunner-policy.json
    echo -e "${GREEN}✓${NC} IAM Policy creata: $IAM_POLICY_NAME"
else
    echo -e "${YELLOW}⚠${NC}  IAM Policy già esistente: $IAM_POLICY_NAME"
fi
echo ""

# Step 5: Crea IAM Role
echo -e "${BLUE}=== Step 5/8: Creazione IAM Role ===${NC}"
ROLE_EXISTS=$(aws iam get-role --role-name $IAM_ROLE_NAME --profile $AWS_PROFILE --query 'Role.RoleName' --output text 2>/dev/null || echo "")

if [ -z "$ROLE_EXISTS" ]; then
    echo "Creazione IAM role..."
    
    # Crea trust policy temporaneo
    cat > /tmp/apprunner-trust-policy.json << EOF
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
EOF
    
    aws iam create-role \
      --role-name $IAM_ROLE_NAME \
      --assume-role-policy-document file:///tmp/apprunner-trust-policy.json \
      --profile $AWS_PROFILE > /dev/null
    
    rm /tmp/apprunner-trust-policy.json
    
    echo "Attaching policy al role..."
    aws iam attach-role-policy \
      --role-name $IAM_ROLE_NAME \
      --policy-arn $POLICY_ARN \
      --profile $AWS_PROFILE
    
    echo -e "${GREEN}✓${NC} IAM Role creato: $IAM_ROLE_NAME"
else
    echo -e "${YELLOW}⚠${NC}  IAM Role già esistente: $IAM_ROLE_NAME"
fi

ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${IAM_ROLE_NAME}"
echo ""

# Step 5b: Crea IAM Access Role per ECR
echo -e "${BLUE}=== Step 5b/9: Creazione IAM Access Role per ECR ===${NC}"
ACCESS_ROLE_EXISTS=$(aws iam get-role --role-name $IAM_ACCESS_ROLE_NAME --profile $AWS_PROFILE --query 'Role.RoleName' --output text 2>/dev/null || echo "")

if [ -z "$ACCESS_ROLE_EXISTS" ]; then
    echo "Creazione IAM access role per ECR..."
    
    # Crea trust policy per App Runner
    cat > /tmp/apprunner-ecr-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "build.apprunner.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
    
    aws iam create-role \
      --role-name $IAM_ACCESS_ROLE_NAME \
      --assume-role-policy-document file:///tmp/apprunner-ecr-trust-policy.json \
      --profile $AWS_PROFILE > /dev/null
    
    rm /tmp/apprunner-ecr-trust-policy.json
    
    echo "Attaching AWSAppRunnerServicePolicyForECRAccess..."
    aws iam attach-role-policy \
      --role-name $IAM_ACCESS_ROLE_NAME \
      --policy-arn arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess \
      --profile $AWS_PROFILE
    
    echo -e "${GREEN}✓${NC} IAM Access Role creato: $IAM_ACCESS_ROLE_NAME"
else
    echo -e "${YELLOW}⚠${NC}  IAM Access Role già esistente: $IAM_ACCESS_ROLE_NAME"
fi

ACCESS_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${IAM_ACCESS_ROLE_NAME}"
echo ""

# Step 6: Crea ECR Repository
echo -e "${BLUE}=== Step 6/8: Creazione ECR Repository ===${NC}"
REPO_EXISTS=$(aws ecr describe-repositories \
  --repository-names $ECR_REPO_NAME \
  --region $AWS_REGION \
  --profile $AWS_PROFILE \
  --query 'repositories[0].repositoryName' --output text 2>/dev/null || echo "")

if [ -z "$REPO_EXISTS" ]; then
    echo "Creazione ECR repository..."
    aws ecr create-repository \
      --repository-name $ECR_REPO_NAME \
      --region $AWS_REGION \
      --profile $AWS_PROFILE > /dev/null
    
    echo -e "${GREEN}✓${NC} ECR Repository creato: $ECR_REPO_NAME"
else
    echo -e "${YELLOW}⚠${NC}  ECR Repository già esistente: $ECR_REPO_NAME"
fi

ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}"
echo ""

# Step 7: Build e Push Docker Image
echo -e "${BLUE}=== Step 7/9: Build e Push Docker Image ===${NC}"
echo "Building Docker image..."
docker build -t $ECR_REPO_NAME:latest . > /dev/null

echo "Login a ECR..."
aws ecr get-login-password --region $AWS_REGION --profile $AWS_PROFILE | \
  docker login --username AWS --password-stdin $ECR_URI > /dev/null 2>&1

echo "Tagging e pushing image..."
docker tag $ECR_REPO_NAME:latest $ECR_URI:latest
docker push $ECR_URI:latest > /dev/null

echo -e "${GREEN}✓${NC} Docker image pushata su ECR"
echo ""

# Step 8: Crea App Runner Service
echo -e "${BLUE}=== Step 8/9: Creazione App Runner Service ===${NC}"
SERVICE_EXISTS=$(aws apprunner list-services \
  --region $AWS_REGION \
  --profile $AWS_PROFILE \
  --query "ServiceSummaryList[?ServiceName=='${APP_RUNNER_SERVICE_NAME}'].ServiceArn" \
  --output text 2>/dev/null || echo "")

if [ -z "$SERVICE_EXISTS" ]; then
    echo "Creazione App Runner service..."
    echo "Questo può richiedere alcuni minuti..."
    
    # Crea configurazione temporanea
    cat > /tmp/apprunner-config.json << EOF
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
EOF
    
    SERVICE_ARN=$(aws apprunner create-service \
      --cli-input-json file:///tmp/apprunner-config.json \
      --region $AWS_REGION \
      --profile $AWS_PROFILE \
      --query 'Service.ServiceArn' \
      --output text)
    
    rm /tmp/apprunner-config.json
    
    echo "Attesa che il servizio sia running..."
    aws apprunner wait service-running \
      --service-arn $SERVICE_ARN \
      --region $AWS_REGION \
      --profile $AWS_PROFILE
    
    echo -e "${GREEN}✓${NC} App Runner Service creato: $APP_RUNNER_SERVICE_NAME"
else
    echo -e "${YELLOW}⚠${NC}  App Runner Service già esistente: $APP_RUNNER_SERVICE_NAME"
    SERVICE_ARN=$SERVICE_EXISTS
fi
echo ""

# Ottieni URL del servizio
SERVICE_URL=$(aws apprunner describe-service \
  --service-arn $SERVICE_ARN \
  --region $AWS_REGION \
  --profile $AWS_PROFILE \
  --query 'Service.ServiceUrl' \
  --output text)

# Riepilogo finale
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           Setup Completato con Successo! 🎉               ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Risorse create:"
echo "  ✓ KMS Key: $KMS_KEY_ALIAS"
echo "  ✓ Secret: $SECRET_NAME"
echo "  ✓ DynamoDB Table: $TABLE_NAME"
echo "  ✓ IAM Policy: $IAM_POLICY_NAME"
echo "  ✓ IAM Role: $IAM_ROLE_NAME"
echo "  ✓ ECR Repository: $ECR_REPO_NAME"
echo "  ✓ App Runner Service: $APP_RUNNER_SERVICE_NAME"
echo ""
echo -e "${BLUE}Service URL:${NC} ${GREEN}https://${SERVICE_URL}${NC}"
echo ""
echo "Test dell'applicazione:"
echo "  curl https://${SERVICE_URL}/health"
echo "  curl https://${SERVICE_URL}/"
echo ""
echo "Documentazione interattiva:"
echo "  https://${SERVICE_URL}/docs"
echo ""
echo -e "${YELLOW}Prossimi passi:${NC}"
echo "  1. Testa l'API con i comandi sopra"
echo "  2. Per deploy futuri, usa: ./deploy.sh"
echo "  3. Per eliminare tutto, usa: ./cleanup-aws.sh"
echo ""
