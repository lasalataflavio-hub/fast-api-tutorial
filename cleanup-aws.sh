#!/bin/bash
# cleanup-aws.sh - Script per eliminare tutte le risorse AWS create
# ⚠️ ATTENZIONE: Questo eliminerà TUTTE le risorse create da setup-aws.sh

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
NC='\033[0m'

# Variabili (usa .env.local o default)
AWS_PROFILE=${AWS_PROFILE:-default}
AWS_REGION=${AWS_REGION:-eu-west-1}
if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo -e "${RED}ERRORE: AWS_ACCOUNT_ID non trovato in .env.local${NC}"
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

echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║  ⚠️  ATTENZIONE: Eliminazione Risorse AWS  ⚠️             ║${NC}"
echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Questo script eliminerà TUTTE le seguenti risorse:${NC}"
echo "  - App Runner Service: $APP_RUNNER_SERVICE_NAME"
echo "  - ECR Repository: $ECR_REPO_NAME (e tutte le immagini)"
echo "  - DynamoDB Table: $TABLE_NAME (e tutti i dati)"
echo "  - Secret: $SECRET_NAME"
echo "  - KMS Key: $KMS_KEY_ALIAS (scheduled deletion)"
echo "  - IAM Role: $IAM_ROLE_NAME"
echo "  - IAM Policy: $IAM_POLICY_NAME"
echo ""
echo -e "${RED}⚠️  Questa operazione è IRREVERSIBILE!${NC}"
echo ""
read -p "Sei ASSOLUTAMENTE sicuro? Digita 'DELETE' per confermare: " confirm

if [ "$confirm" != "DELETE" ]; then
    echo "Operazione annullata."
    exit 0
fi

echo ""
echo "Inizio eliminazione risorse..."
echo ""

# 1. Elimina App Runner Service
echo -e "${YELLOW}[1/7]${NC} Eliminazione App Runner Service..."
SERVICE_ARN=$(aws apprunner list-services \
  --region $AWS_REGION \
  --profile $AWS_PROFILE \
  --query "ServiceSummaryList[?ServiceName=='${APP_RUNNER_SERVICE_NAME}'].ServiceArn" \
  --output text 2>/dev/null || echo "")

if [ -n "$SERVICE_ARN" ]; then
    aws apprunner delete-service \
      --service-arn $SERVICE_ARN \
      --region $AWS_REGION \
      --profile $AWS_PROFILE > /dev/null
    echo -e "${GREEN}✓${NC} App Runner Service eliminato"
else
    echo -e "${YELLOW}⚠${NC}  App Runner Service non trovato"
fi

# 2. Elimina ECR Repository
echo -e "${YELLOW}[2/7]${NC} Eliminazione ECR Repository..."
REPO_EXISTS=$(aws ecr describe-repositories \
  --repository-names $ECR_REPO_NAME \
  --region $AWS_REGION \
  --profile $AWS_PROFILE \
  --query 'repositories[0].repositoryName' --output text 2>/dev/null || echo "")

if [ -n "$REPO_EXISTS" ]; then
    aws ecr delete-repository \
      --repository-name $ECR_REPO_NAME \
      --region $AWS_REGION \
      --profile $AWS_PROFILE \
      --force > /dev/null
    echo -e "${GREEN}✓${NC} ECR Repository eliminato"
else
    echo -e "${YELLOW}⚠${NC}  ECR Repository non trovato"
fi

# 3. Elimina DynamoDB Table
echo -e "${YELLOW}[3/7]${NC} Eliminazione DynamoDB Table..."
TABLE_EXISTS=$(aws dynamodb describe-table \
  --table-name $TABLE_NAME \
  --region $AWS_REGION \
  --profile $AWS_PROFILE \
  --query 'Table.TableName' --output text 2>/dev/null || echo "")

if [ -n "$TABLE_EXISTS" ]; then
    aws dynamodb delete-table \
      --table-name $TABLE_NAME \
      --region $AWS_REGION \
      --profile $AWS_PROFILE > /dev/null
    echo -e "${GREEN}✓${NC} DynamoDB Table eliminata"
else
    echo -e "${YELLOW}⚠${NC}  DynamoDB Table non trovata"
fi

# 4. Elimina Secret
echo -e "${YELLOW}[4/7]${NC} Eliminazione Secret..."
SECRET_EXISTS=$(aws secretsmanager describe-secret \
  --secret-id $SECRET_NAME \
  --region $AWS_REGION \
  --profile $AWS_PROFILE \
  --query 'Name' --output text 2>/dev/null || echo "")

if [ -n "$SECRET_EXISTS" ]; then
    aws secretsmanager delete-secret \
      --secret-id $SECRET_NAME \
      --force-delete-without-recovery \
      --region $AWS_REGION \
      --profile $AWS_PROFILE > /dev/null
    echo -e "${GREEN}✓${NC} Secret eliminato"
else
    echo -e "${YELLOW}⚠${NC}  Secret non trovato"
fi

# 5. Schedule KMS Key deletion
echo -e "${YELLOW}[5/7]${NC} Schedule KMS Key deletion..."
KMS_KEY_ID=$(aws kms list-aliases \
  --profile $AWS_PROFILE \
  --region $AWS_REGION \
  --query "Aliases[?AliasName=='${KMS_KEY_ALIAS}'].TargetKeyId" \
  --output text 2>/dev/null || echo "")

if [ -n "$KMS_KEY_ID" ]; then
    # Elimina alias
    aws kms delete-alias \
      --alias-name $KMS_KEY_ALIAS \
      --region $AWS_REGION \
      --profile $AWS_PROFILE 2>/dev/null || true
    
    # Schedule key deletion (minimo 7 giorni)
    aws kms schedule-key-deletion \
      --key-id $KMS_KEY_ID \
      --pending-window-in-days 7 \
      --region $AWS_REGION \
      --profile $AWS_PROFILE > /dev/null
    echo -e "${GREEN}✓${NC} KMS Key scheduled for deletion (7 giorni)"
else
    echo -e "${YELLOW}⚠${NC}  KMS Key non trovata"
fi

# 6. Elimina IAM Role
echo -e "${YELLOW}[6/7]${NC} Eliminazione IAM Role..."
ROLE_EXISTS=$(aws iam get-role \
  --role-name $IAM_ROLE_NAME \
  --profile $AWS_PROFILE \
  --query 'Role.RoleName' --output text 2>/dev/null || echo "")

if [ -n "$ROLE_EXISTS" ]; then
    # Detach policy
    POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${IAM_POLICY_NAME}"
    aws iam detach-role-policy \
      --role-name $IAM_ROLE_NAME \
      --policy-arn $POLICY_ARN \
      --profile $AWS_PROFILE 2>/dev/null || true
    
    # Delete role
    aws iam delete-role \
      --role-name $IAM_ROLE_NAME \
      --profile $AWS_PROFILE > /dev/null
    echo -e "${GREEN}✓${NC} IAM Role eliminato"
else
    echo -e "${YELLOW}⚠${NC}  IAM Role non trovato"
fi

# 7. Elimina IAM Policy
echo -e "${YELLOW}[7/8]${NC} Eliminazione IAM Policy..."
POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${IAM_POLICY_NAME}"
POLICY_EXISTS=$(aws iam get-policy \
  --policy-arn $POLICY_ARN \
  --profile $AWS_PROFILE \
  --query 'Policy.Arn' --output text 2>/dev/null || echo "")

if [ -n "$POLICY_EXISTS" ]; then
    aws iam delete-policy \
      --policy-arn $POLICY_ARN \
      --profile $AWS_PROFILE > /dev/null
    echo -e "${GREEN}✓${NC} IAM Policy eliminata"
else
    echo -e "${YELLOW}⚠${NC}  IAM Policy non trovata"
fi

# 8. Elimina IAM Access Role per ECR
echo -e "${YELLOW}[8/8]${NC} Eliminazione IAM Access Role..."
ACCESS_ROLE_EXISTS=$(aws iam get-role \
  --role-name $IAM_ACCESS_ROLE_NAME \
  --profile $AWS_PROFILE \
  --query 'Role.RoleName' --output text 2>/dev/null || echo "")

if [ -n "$ACCESS_ROLE_EXISTS" ]; then
    # Detach managed policy
    aws iam detach-role-policy \
      --role-name $IAM_ACCESS_ROLE_NAME \
      --policy-arn arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess \
      --profile $AWS_PROFILE 2>/dev/null || true
    
    # Delete role
    aws iam delete-role \
      --role-name $IAM_ACCESS_ROLE_NAME \
      --profile $AWS_PROFILE > /dev/null
    echo -e "${GREEN}✓${NC} IAM Access Role eliminato"
else
    echo -e "${YELLOW}⚠${NC}  IAM Access Role non trovato"
fi

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           Cleanup Completato! ✓                           ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Tutte le risorse sono state eliminate."
echo ""
echo -e "${YELLOW}Nota:${NC} La KMS Key sarà eliminata definitivamente tra 7 giorni."
echo "      Puoi annullare la deletion con:"
echo "      aws kms cancel-key-deletion --key-id <key-id> --profile $AWS_PROFILE"
echo ""
