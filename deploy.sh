#!/bin/bash
# deploy.sh - Script per deploy rapido su AWS App Runner

set -e

# Carica variabili da .env.local se esiste
if [ -f .env.local ]; then
    echo "Caricamento configurazione da .env.local..."
    export $(grep -v '^#' .env.local | xargs)
fi

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Variabili (usa .env.local o default)
AWS_PROFILE=${AWS_PROFILE:-default}
AWS_REGION=${AWS_REGION:-eu-west-1}
if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo -e "${RED}ERRORE: AWS_ACCOUNT_ID non trovato in .env.local${NC}"
    exit 1
fi
ECR_REPO_NAME=${ECR_REPO_NAME:-fastapi-docker-example}
ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}"

echo -e "${GREEN}=== FastAPI AWS Tutorial - Deploy Script ===${NC}"
echo ""

# Verifica che AWS CLI sia configurato
if ! aws sts get-caller-identity --profile $AWS_PROFILE &> /dev/null; then
    echo -e "${RED}❌ AWS CLI profile non configurato. Esegui 'aws configure --profile [your-profile]'${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} AWS CLI configurato"
echo -e "  Profile: ${AWS_PROFILE}"
echo -e "  Account: ${AWS_ACCOUNT_ID}"
echo -e "  Region: ${AWS_REGION}"
echo ""

# Build Docker image
echo -e "${YELLOW}=== 1/4 Build Docker Image ===${NC}"
docker build -t ${ECR_REPO_NAME}:latest .
echo -e "${GREEN}✓${NC} Build completato"
echo ""

# Login a ECR
echo -e "${YELLOW}=== 2/4 Login ECR ===${NC}"
aws ecr get-login-password --region ${AWS_REGION} --profile ${AWS_PROFILE} | \
  docker login --username AWS --password-stdin ${ECR_URI}
echo -e "${GREEN}✓${NC} Login ECR completato"
echo ""

# Tag e Push
echo -e "${YELLOW}=== 3/4 Tag e Push Image ===${NC}"
docker tag ${ECR_REPO_NAME}:latest ${ECR_URI}:latest
docker push ${ECR_URI}:latest
echo -e "${GREEN}✓${NC} Push completato"
echo ""

# Verifica App Runner
echo -e "${YELLOW}=== 4/4 Verifica App Runner ===${NC}"
SERVICE_ARN=$(aws apprunner list-services --region ${AWS_REGION} --profile ${AWS_PROFILE} \
  --query "ServiceSummaryList[?ServiceName=='fastapi-tutorial-service'].ServiceArn" \
  --output text 2>/dev/null || echo "")

if [ -z "$SERVICE_ARN" ]; then
    echo -e "${YELLOW}⚠${NC}  Servizio App Runner non trovato"
    echo -e "   Crea il servizio seguendo la guida in docs/SETUP.md"
else
    echo -e "${GREEN}✓${NC} Servizio App Runner trovato"
    echo -e "   ARN: ${SERVICE_ARN}"
    echo -e "   App Runner aggiornerà automaticamente il servizio"
    
    # Ottieni URL del servizio
    SERVICE_URL=$(aws apprunner describe-service \
      --service-arn ${SERVICE_ARN} \
      --region ${AWS_REGION} \
      --profile ${AWS_PROFILE} \
      --query 'Service.ServiceUrl' \
      --output text)
    
    echo -e "   URL: ${GREEN}https://${SERVICE_URL}${NC}"
fi

echo ""
echo -e "${GREEN}=== Deploy Completato! ===${NC}"
echo ""
echo "Prossimi passi:"
echo "  1. Attendi che App Runner completi il deployment (~2-3 minuti)"
echo "  2. Testa l'API: curl https://${SERVICE_URL}/health"
echo "  3. Visualizza documentazione: https://${SERVICE_URL}/docs"
echo ""
