# Guida Setup AWS - FastAPI Tutorial

Questa guida ti accompagna passo-passo nella configurazione dell'infrastruttura AWS necessaria per il progetto didattico.

## Prerequisiti

- Account AWS attivo
- AWS CLI installato e configurato con profile 'plug' (`aws configure --profile plug`)
- Docker installato
- Permessi AWS per creare: DynamoDB tables, KMS keys, Secrets Manager secrets, IAM roles, ECR repositories, App Runner services

**Nota**: Tutti i comandi in questa guida usano il profile AWS 'plug'. Assicurati di averlo configurato:

```bash
# Configura il profile plug
aws configure --profile plug

# Verifica il profile
aws sts get-caller-identity --profile plug
```

## Variabili di Configurazione

Prima di iniziare, definisci queste variabili (modifica secondo le tue esigenze):

```bash
export AWS_PROFILE=plug
export AWS_REGION=eu-west-1
export AWS_ACCOUNT_ID=123456789012  # Sostituisci con il tuo AWS Account ID
export TABLE_NAME=fastapi-tutorial-items
export SECRET_NAME=fastapi-tutorial-secrets
export KMS_KEY_ALIAS=alias/fastapi-tutorial-key
export ECR_REPO_NAME=fastapi-docker-example
export APP_RUNNER_SERVICE_NAME=fastapi-tutorial-service
```

**Importante**: Tutti i comandi AWS CLI useranno `--profile plug`.

## Step 1: Creare KMS Key per Encryption

Crea una chiave KMS dedicata per criptare i secrets:

```bash
# Crea la KMS key
aws kms create-key \
  --description "KMS key per FastAPI Tutorial secrets" \
  --region $AWS_REGION \
  --profile $AWS_PROFILE

# Salva il Key ID dalla risposta
export KMS_KEY_ID=<key-id-dalla-risposta>

# Crea un alias per la key (più facile da ricordare)
aws kms create-alias \
  --alias-name $KMS_KEY_ALIAS \
  --target-key-id $KMS_KEY_ID \
  --region $AWS_REGION \
  --profile $AWS_PROFILE
```

Verifica la creazione:

```bash
aws kms describe-key --key-id $KMS_KEY_ALIAS --region $AWS_REGION --profile $AWS_PROFILE
```

## Step 2: Creare Secret in Secrets Manager

Crea il secret con valori di esempio (modifica secondo necessità):

```bash
# Crea il secret con encryption KMS
aws secretsmanager create-secret \
  --name $SECRET_NAME \
  --description "Secrets per FastAPI Tutorial" \
  --kms-key-id $KMS_KEY_ID \
  --secret-string '{"api_key":"demo-api-key-12345","database_encryption_key":"demo-encryption-key"}' \
  --region $AWS_REGION \
  --profile $AWS_PROFILE
```

Verifica il secret:

```bash
# Recupera il secret (per testare)
aws secretsmanager get-secret-value \
  --secret-id $SECRET_NAME \
  --region $AWS_REGION \
  --profile $AWS_PROFILE
```

Salva l'ARN del secret (lo userai dopo):

```bash
export SECRET_ARN=$(aws secretsmanager describe-secret \
  --secret-id $SECRET_NAME \
  --region $AWS_REGION \
  --profile $AWS_PROFILE \
  --query 'ARN' \
  --output text)

echo "Secret ARN: $SECRET_ARN"
```

## Step 3: Creare Tabella DynamoDB

Crea la tabella DynamoDB con billing on-demand:

```bash
aws dynamodb create-table \
  --table-name $TABLE_NAME \
  --attribute-definitions AttributeName=item_id,AttributeType=S \
  --key-schema AttributeName=item_id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region $AWS_REGION \
  --profile $AWS_PROFILE
```

Attendi che la tabella sia attiva:

```bash
aws dynamodb wait table-exists \
  --table-name $TABLE_NAME \
  --region $AWS_REGION \
  --profile $AWS_PROFILE

echo "Tabella DynamoDB creata con successo!"
```

Verifica la tabella:

```bash
aws dynamodb describe-table \
  --table-name $TABLE_NAME \
  --region $AWS_REGION \
  --profile $AWS_PROFILE
```

## Step 4: Creare IAM Role per App Runner

Crea una policy IAM con i permessi necessari:

```bash
# Crea il file della policy
cat > apprunner-policy.json << EOF
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

# Crea la policy
aws iam create-policy \
  --policy-name FastAPITutorialAppRunnerPolicy \
  --policy-document file://apprunner-policy.json \
  --profile $AWS_PROFILE

export POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/FastAPITutorialAppRunnerPolicy"
```

Crea il role IAM per App Runner:

```bash
# Crea il trust policy per App Runner
cat > apprunner-trust-policy.json << EOF
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

# Crea il role
aws iam create-role \
  --role-name FastAPITutorialAppRunnerRole \
  --assume-role-policy-document file://apprunner-trust-policy.json \
  --profile $AWS_PROFILE

# Attacca la policy al role
aws iam attach-role-policy \
  --role-name FastAPITutorialAppRunnerRole \
  --policy-arn $POLICY_ARN \
  --profile $AWS_PROFILE

export ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/FastAPITutorialAppRunnerRole"

echo "IAM Role ARN: $ROLE_ARN"
```

## Step 5: Build e Push Docker Image su ECR

Crea il repository ECR (se non esiste già):

```bash
# Crea repository ECR
aws ecr create-repository \
  --repository-name $ECR_REPO_NAME \
  --region $AWS_REGION \
  --profile $AWS_PROFILE

# Ottieni l'URI del repository
export ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}"
echo "ECR URI: $ECR_URI"
```

Build e push dell'immagine Docker:

```bash
# Login a ECR
aws ecr get-login-password --region $AWS_REGION --profile $AWS_PROFILE | \
  docker login --username AWS --password-stdin $ECR_URI

# Build dell'immagine
docker build -t $ECR_REPO_NAME:latest .

# Tag dell'immagine
docker tag $ECR_REPO_NAME:latest $ECR_URI:latest

# Push su ECR
docker push $ECR_URI:latest

echo "Immagine Docker pushata su ECR con successo!"
```

## Step 6: Creare/Aggiornare Servizio App Runner

### Opzione A: Creare Nuovo Servizio

Se è la prima volta che crei il servizio:

```bash
# Crea il file di configurazione
cat > apprunner-config.json << EOF
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

# Crea il servizio
aws apprunner create-service \
  --cli-input-json file://apprunner-config.json \
  --region $AWS_REGION \
  --profile $AWS_PROFILE
```

### Opzione B: Aggiornare Servizio Esistente

Se il servizio esiste già e vuoi solo aggiornare l'immagine:

```bash
# Ottieni l'ARN del servizio
export SERVICE_ARN=$(aws apprunner list-services \
  --region $AWS_REGION \
  --profile $AWS_PROFILE \
  --query "ServiceSummaryList[?ServiceName=='${APP_RUNNER_SERVICE_NAME}'].ServiceArn" \
  --output text)

# Aggiorna il servizio con la nuova immagine
aws apprunner update-service \
  --service-arn $SERVICE_ARN \
  --source-configuration "ImageRepository={ImageIdentifier=${ECR_URI}:latest,ImageRepositoryType=ECR,ImageConfiguration={Port=8000,RuntimeEnvironmentVariables={AWS_REGION=${AWS_REGION},DYNAMODB_TABLE_NAME=${TABLE_NAME},SECRET_NAME=${SECRET_NAME},APP_NAME=FastAPI AWS Tutorial,DEBUG=false}}}" \
  --instance-configuration "InstanceRoleArn=${ROLE_ARN}" \
  --region $AWS_REGION \
  --profile $AWS_PROFILE
```

Attendi che il deployment sia completato:

```bash
aws apprunner wait service-running \
  --service-arn $SERVICE_ARN \
  --region $AWS_REGION \
  --profile $AWS_PROFILE

echo "Servizio App Runner deployato con successo!"
```

## Step 7: Ottenere URL del Servizio e Testare

Ottieni l'URL pubblico del servizio:

```bash
export SERVICE_URL=$(aws apprunner describe-service \
  --service-arn $SERVICE_ARN \
  --region $AWS_REGION \
  --profile $AWS_PROFILE \
  --query 'Service.ServiceUrl' \
  --output text)

echo "Service URL: https://${SERVICE_URL}"
```

Testa l'applicazione:

```bash
# Test endpoint root
curl https://${SERVICE_URL}/

# Test health check
curl https://${SERVICE_URL}/health

# Test config
curl https://${SERVICE_URL}/config

# Crea un item di test
curl -X POST https://${SERVICE_URL}/items \
  -H "Content-Type: application/json" \
  -d '{"name":"Test Item","description":"Item di test","tags":["test","demo"]}'

# Lista items
curl https://${SERVICE_URL}/items
```

## Script di Deploy Completo

Per semplificare i deploy futuri, puoi usare questo script:

```bash
#!/bin/bash
# deploy.sh - Script per deploy rapido

set -e

# Variabili
AWS_PROFILE=plug
AWS_REGION=eu-west-1
AWS_ACCOUNT_ID=123456789012  # Sostituisci con il tuo AWS Account ID
ECR_REPO_NAME=fastapi-docker-example
ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}"

echo "=== Build Docker Image ==="
docker build -t $ECR_REPO_NAME:latest .

echo "=== Login ECR ==="
aws ecr get-login-password --region $AWS_REGION --profile $AWS_PROFILE | \
  docker login --username AWS --password-stdin $ECR_URI

echo "=== Tag e Push ==="
docker tag $ECR_REPO_NAME:latest $ECR_URI:latest
docker push $ECR_URI:latest

echo "=== Deploy completato! ==="
echo "App Runner aggiornerà automaticamente il servizio."
```

Rendi lo script eseguibile:

```bash
chmod +x deploy.sh
```

## Troubleshooting

### Problema: App Runner non riesce ad accedere a DynamoDB

**Soluzione**: Verifica che il role IAM sia correttamente configurato:

```bash
# Verifica le policy attaccate al role
aws iam list-attached-role-policies \
  --role-name FastAPITutorialAppRunnerRole \
  --profile $AWS_PROFILE

# Verifica il contenuto della policy
aws iam get-policy-version \
  --policy-arn $POLICY_ARN \
  --version-id v1 \
  --profile $AWS_PROFILE
```

### Problema: Secrets non vengono caricati

**Soluzione**: Verifica i permessi KMS:

```bash
# Verifica che il role possa usare la KMS key
aws kms describe-key --key-id $KMS_KEY_ALIAS --region $AWS_REGION --profile $AWS_PROFILE
```

### Problema: Health check fallisce

**Soluzione**: Controlla i log di App Runner:

```bash
# Visualizza i log
aws apprunner list-operations \
  --service-arn $SERVICE_ARN \
  --region $AWS_REGION \
  --profile $AWS_PROFILE
```

## Cleanup (Rimozione Risorse)

Per rimuovere tutte le risorse create:

```bash
# Elimina servizio App Runner
aws apprunner delete-service --service-arn $SERVICE_ARN --region $AWS_REGION --profile $AWS_PROFILE

# Elimina tabella DynamoDB
aws dynamodb delete-table --table-name $TABLE_NAME --region $AWS_REGION --profile $AWS_PROFILE

# Elimina secret
aws secretsmanager delete-secret \
  --secret-id $SECRET_NAME \
  --force-delete-without-recovery \
  --region $AWS_REGION \
  --profile $AWS_PROFILE

# Elimina KMS key (schedule deletion)
aws kms schedule-key-deletion \
  --key-id $KMS_KEY_ID \
  --pending-window-in-days 7 \
  --region $AWS_REGION \
  --profile $AWS_PROFILE

# Detach e elimina policy IAM
aws iam detach-role-policy \
  --role-name FastAPITutorialAppRunnerRole \
  --policy-arn $POLICY_ARN \
  --profile $AWS_PROFILE

aws iam delete-role --role-name FastAPITutorialAppRunnerRole --profile $AWS_PROFILE

aws iam delete-policy --policy-arn $POLICY_ARN --profile $AWS_PROFILE
```

## Prossimi Passi

- Consulta [ARCHITECTURE.md](./ARCHITECTURE.md) per capire l'architettura
- Leggi [CODE_GUIDE.md](./CODE_GUIDE.md) per un walkthrough del codice
- Vedi [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) per problemi comuni
