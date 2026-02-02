# Troubleshooting - FastAPI AWS Tutorial

Questa guida ti aiuta a risolvere i problemi più comuni.

**⚠️ IMPORTANTE**: Tutti i comandi AWS CLI in questa guida usano il profile `plug`. Assicurati di averlo configurato:

```bash
# Configura il profile plug
aws configure --profile plug

# Oppure esporta come variabile d'ambiente
export AWS_PROFILE=plug

# Verifica
aws sts get-caller-identity --profile plug
```

Se hai esportato `AWS_PROFILE=plug`, puoi omettere `--profile plug` dai comandi.

## Indice

- [Problemi di Setup AWS](#problemi-di-setup-aws)
- [Problemi di Connessione DynamoDB](#problemi-di-connessione-dynamodb)
- [Problemi con Secrets Manager](#problemi-con-secrets-manager)
- [Problemi di Deploy su App Runner](#problemi-di-deploy-su-app-runner)
- [Problemi di Logging](#problemi-di-logging)
- [Errori Comuni nell'Applicazione](#errori-comuni-nellapplicazione)
- [FAQ](#faq)

---

## Problemi di Setup AWS

### Errore: "AccessDeniedException" durante creazione risorse

**Sintomo**:
```
An error occurred (AccessDeniedException) when calling the CreateTable operation
```

**Causa**: Il tuo utente AWS non ha i permessi necessari.

**Soluzione**:
```bash
# Verifica le tue credenziali con il profile plug
aws sts get-caller-identity --profile plug

# Verifica i permessi dell'utente
aws iam get-user --user-name <your-username> --profile plug

# Chiedi all'amministratore di aggiungere le policy necessarie:
# - AmazonDynamoDBFullAccess
# - SecretsManagerReadWrite
# - AWSKeyManagementServicePowerUser
# - AWSAppRunnerFullAccess
```

### Errore: "Region not specified"

**Sintomo**:
```
You must specify a region
```

**Causa**: AWS CLI non ha una region configurata.

**Soluzione**:
```bash
# Configura la region per il profile plug
aws configure set region eu-west-1 --profile plug

# Oppure usa variabile d'ambiente
export AWS_REGION=eu-west-1
export AWS_PROFILE=plug

# Verifica
aws configure get region --profile plug
```

### Errore: KMS Key non trovata

**Sintomo**:
```
NotFoundException: Key 'alias/fastapi-tutorial-key' not found
```

**Causa**: L'alias KMS non esiste o è in una region diversa.

**Soluzione**:
```bash
# Lista tutte le KMS keys
aws kms list-keys --region eu-west-1 --profile plug

# Lista gli alias
aws kms list-aliases --region eu-west-1 --profile plug

# Verifica che l'alias punti alla key corretta
aws kms describe-key --key-id alias/fastapi-tutorial-key --region eu-west-1 --profile plug
```

---

## Problemi di Connessione DynamoDB

### Errore: "ResourceNotFoundException: Table not found"

**Sintomo**:
```json
{
  "error": "AWSServiceError",
  "message": "Errore nella comunicazione con i servizi AWS",
  "detail": "ResourceNotFoundException"
}
```

**Causa**: La tabella DynamoDB non esiste o il nome è errato.

**Soluzione**:
```bash
# Verifica che la tabella esista
aws dynamodb describe-table \
  --table-name fastapi-tutorial-items \
  --region eu-west-1

# Se non esiste, creala
aws dynamodb create-table \
  --table-name fastapi-tutorial-items \
  --attribute-definitions AttributeName=item_id,AttributeType=S \
  --key-schema AttributeName=item_id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region eu-west-1

# Verifica il nome della tabella nelle variabili d'ambiente
echo $DYNAMODB_TABLE_NAME
```

### Errore: "AccessDeniedException" su DynamoDB

**Sintomo**:
```
User is not authorized to perform: dynamodb:PutItem on resource
```

**Causa**: Il role IAM di App Runner non ha i permessi necessari.

**Soluzione**:
```bash
# Verifica le policy attaccate al role
aws iam list-attached-role-policies \
  --role-name FastAPITutorialAppRunnerRole

# Verifica il contenuto della policy
aws iam get-policy-version \
  --policy-arn arn:aws:iam::123456789012:policy/FastAPITutorialAppRunnerPolicy \
  --version-id v1

# La policy deve includere:
# - dynamodb:PutItem
# - dynamodb:GetItem
# - dynamodb:Scan
# - dynamodb:DeleteItem
# - dynamodb:DescribeTable
```

### Health Check Fallisce

**Sintomo**: `/health` ritorna `"database": "error"`

**Debug**:
```bash
# Test connessione locale
aws dynamodb describe-table \
  --table-name fastapi-tutorial-items \
  --region eu-west-1

# Verifica log dell'applicazione
# Cerca errori tipo "Health check FAILED"
```

**Soluzioni comuni**:
1. Verifica che la tabella sia ACTIVE
2. Verifica IAM permissions
3. Verifica che la region sia corretta
4. Verifica network connectivity (VPC/Security Groups se applicabile)

---

## Problemi con Secrets Manager

### Errore: "ResourceNotFoundException: Secret not found"

**Sintomo**:
```
Impossibile caricare secrets: An error occurred (ResourceNotFoundException)
```

**Causa**: Il secret non esiste o il nome è errato.

**Soluzione**:
```bash
# Lista tutti i secrets
aws secretsmanager list-secrets --region eu-west-1

# Verifica il nome del secret
echo $SECRET_NAME

# Se non esiste, crealo
aws secretsmanager create-secret \
  --name fastapi-tutorial-secrets \
  --secret-string '{"api_key":"demo-key","database_encryption_key":"demo-enc-key"}' \
  --region eu-west-1
```

### Errore: "AccessDeniedException" su Secrets Manager

**Sintomo**:
```
User is not authorized to perform: secretsmanager:GetSecretValue
```

**Causa**: Il role IAM non ha permessi su Secrets Manager.

**Soluzione**:
```bash
# Verifica che la policy includa:
# - secretsmanager:GetSecretValue
# - secretsmanager:DescribeSecret

# Verifica anche i permessi KMS per decriptare:
# - kms:Decrypt
# - kms:DescribeKey
```

### Secret non viene decriptato

**Sintomo**: Errore durante il recupero del secret.

**Causa**: Mancano permessi KMS per decriptare.

**Soluzione**:
```bash
# Verifica la KMS key usata dal secret
aws secretsmanager describe-secret \
  --secret-id fastapi-tutorial-secrets \
  --region eu-west-1 \
  --query 'KmsKeyId'

# Verifica permessi sulla KMS key
aws kms get-key-policy \
  --key-id <key-id> \
  --policy-name default \
  --region eu-west-1

# Il role deve avere permesso kms:Decrypt
```

### Secret in formato non valido

**Sintomo**:
```
Secret 'fastapi-tutorial-secrets' non è JSON valido
```

**Causa**: Il secret non è in formato JSON.

**Soluzione**:
```bash
# Verifica il formato del secret
aws secretsmanager get-secret-value \
  --secret-id fastapi-tutorial-secrets \
  --region eu-west-1 \
  --query 'SecretString'

# Deve essere JSON valido:
# {"api_key":"value","database_encryption_key":"value"}

# Aggiorna il secret se necessario
aws secretsmanager update-secret \
  --secret-id fastapi-tutorial-secrets \
  --secret-string '{"api_key":"new-value"}' \
  --region eu-west-1
```

---

## Problemi di Deploy su App Runner

### Build Docker Fallisce

**Sintomo**:
```
ERROR: failed to solve: failed to compute cache key
```

**Causa**: Problemi nel Dockerfile o file mancanti.

**Soluzione**:
```bash
# Test build locale
docker build -t fastapi-test .

# Verifica che tutti i file necessari esistano
ls -la app/
ls requirements.txt

# Verifica .dockerignore non escluda file necessari
cat .dockerignore
```

### Push su ECR Fallisce

**Sintomo**:
```
denied: Your authorization token has expired
```

**Causa**: Token ECR scaduto.

**Soluzione**:
```bash
# Re-login a ECR
aws ecr get-login-password --region eu-west-1 | \
  docker login --username AWS --password-stdin \
  123456789012.dkr.ecr.eu-west-1.amazonaws.com

# Poi riprova il push
docker push 123456789012.dkr.ecr.eu-west-1.amazonaws.com/fastapi-docker-example:latest
```

### App Runner Service non si avvia

**Sintomo**: Service rimane in stato "OPERATION_IN_PROGRESS" o "CREATE_FAILED"

**Debug**:
```bash
# Controlla lo stato del servizio
aws apprunner describe-service \
  --service-arn <service-arn> \
  --region eu-west-1

# Visualizza le operations
aws apprunner list-operations \
  --service-arn <service-arn> \
  --region eu-west-1

# Controlla i log
aws logs tail /aws/apprunner/<service-name>/service --follow
```

**Soluzioni comuni**:
1. Verifica che l'immagine Docker sia valida
2. Verifica che la porta 8000 sia esposta
3. Verifica che le variabili d'ambiente siano corrette
4. Verifica che il role IAM sia configurato

### Health Check Fallisce su App Runner

**Sintomo**: Service si riavvia continuamente.

**Causa**: L'endpoint `/health` non risponde correttamente.

**Soluzione**:
```bash
# Test locale dell'health check
curl http://localhost:8000/health

# Deve ritornare:
# {"status":"healthy","database":"connected","timestamp":"..."}

# Verifica configurazione health check in App Runner
aws apprunner describe-service \
  --service-arn <service-arn> \
  --query 'Service.HealthCheckConfiguration'

# Configurazione corretta:
# - Protocol: HTTP
# - Path: /health
# - Interval: 10
# - Timeout: 5
```

### Variabili d'Ambiente non Caricate

**Sintomo**: Applicazione usa valori di default invece di quelli configurati.

**Causa**: Variabili non configurate in App Runner.

**Soluzione**:
```bash
# Verifica variabili configurate
aws apprunner describe-service \
  --service-arn <service-arn> \
  --query 'Service.SourceConfiguration.ImageRepository.ImageConfiguration.RuntimeEnvironmentVariables'

# Aggiorna variabili
aws apprunner update-service \
  --service-arn <service-arn> \
  --source-configuration "ImageRepository={ImageConfiguration={RuntimeEnvironmentVariables={AWS_REGION=eu-west-1,DYNAMODB_TABLE_NAME=fastapi-tutorial-items}}}"
```

---

## Problemi di Logging

### Log non Visibili in CloudWatch

**Sintomo**: Non vedi log in CloudWatch Logs.

**Causa**: Log group non creato o permessi mancanti.

**Soluzione**:
```bash
# Verifica che il log group esista
aws logs describe-log-groups \
  --log-group-name-prefix /aws/apprunner \
  --region eu-west-1

# App Runner crea automaticamente i log groups
# Se non esistono, verifica che il servizio sia running

# Visualizza log
aws logs tail /aws/apprunner/<service-name>/service --follow
```

### Log non in Formato JSON

**Sintomo**: Log sono in formato testo invece di JSON.

**Causa**: `python-json-logger` non installato o non configurato.

**Soluzione**:
```bash
# Verifica che sia in requirements.txt
grep python-json-logger requirements.txt

# Verifica che setup_logging() sia chiamato
# in app/main.py prima di qualsiasi log
```

### Valori Sensibili nei Log

**Sintomo**: API keys o secrets visibili nei log.

**Causa**: Logging non configurato correttamente.

**Soluzione**:
```python
# Verifica che CustomJsonFormatter redacti i valori sensibili
# in app/logging_config.py

# Usa sempre safe_dict() per loggare config
logger.info("Config", extra=settings.safe_dict())

# Non loggare mai direttamente secrets
logger.info(f"API Key: {api_key}")  # ❌ SBAGLIATO
logger.info("API Key loaded")  # ✅ CORRETTO
```

---

## Errori Comuni nell'Applicazione

### Errore 422: Validation Error

**Sintomo**:
```json
{
  "detail": [
    {
      "loc": ["body", "name"],
      "msg": "field required",
      "type": "value_error.missing"
    }
  ]
}
```

**Causa**: Input non valido secondo il modello Pydantic.

**Soluzione**:
```bash
# Verifica il formato della richiesta
curl -X POST http://localhost:8000/items \
  -H "Content-Type: application/json" \
  -d '{"name":"Test Item","description":"Desc","tags":["tag1"]}'

# Assicurati che:
# - Content-Type sia application/json
# - Il JSON sia valido
# - Tutti i campi required siano presenti
# - I tipi siano corretti (string, array, etc.)
```

### Errore 404: Item Not Found

**Sintomo**:
```json
{
  "error": "ItemNotFound",
  "message": "Item con ID 'xyz' non trovato"
}
```

**Causa**: L'item richiesto non esiste in DynamoDB.

**Soluzione**:
```bash
# Verifica che l'item esista
aws dynamodb get-item \
  --table-name fastapi-tutorial-items \
  --key '{"item_id":{"S":"xyz"}}' \
  --region eu-west-1

# Lista tutti gli items
curl http://localhost:8000/items

# Usa un item_id valido dalla lista
```

### Errore 503: Service Unavailable

**Sintomo**:
```json
{
  "error": "AWSServiceError",
  "message": "Errore nella comunicazione con i servizi AWS"
}
```

**Causa**: Problemi di connessione con DynamoDB o altri servizi AWS.

**Debug**:
```bash
# Verifica connettività AWS
aws dynamodb describe-table \
  --table-name fastapi-tutorial-items \
  --region eu-west-1

# Controlla i log per dettagli
# Cerca "ClientError" o "ConnectionError"
```

### Errore 500: Internal Server Error

**Sintomo**: Errore generico del server.

**Debug**:
```bash
# Controlla i log per stack trace
aws logs tail /aws/apprunner/<service-name>/service --follow

# Cerca "ERROR" o "Exception"
# Lo stack trace ti dirà esattamente dove è l'errore
```

---

## FAQ

### Q: Come faccio a testare localmente senza AWS?

**A**: Puoi usare LocalStack o moto per mock dei servizi AWS:

```bash
# Installa moto
pip install moto[all]

# Usa in test
from moto import mock_dynamodb, mock_secretsmanager

@mock_dynamodb
def test_create_item():
    # Il codice userà DynamoDB mockato
    pass
```

### Q: Posso usare una region diversa da eu-west-1?

**A**: Sì, basta cambiare la variabile `AWS_REGION`:

```bash
# In .env o environment variables
AWS_REGION=us-east-1

# Ricorda di creare tutte le risorse nella stessa region
```

### Q: Come faccio a vedere i costi AWS?

**A**: Usa AWS Cost Explorer:

```bash
# Via CLI
aws ce get-cost-and-usage \
  --time-period Start=2025-02-01,End=2025-02-28 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=SERVICE

# Oppure vai su AWS Console → Cost Explorer
```

### Q: Posso usare RDS invece di DynamoDB?

**A**: Sì, ma dovrai:
1. Modificare `database.py` per usare SQLAlchemy
2. Gestire connection pooling
3. Configurare VPC per App Runner (più complesso)

DynamoDB è più semplice per questo tutorial.

### Q: Come faccio il rollback di un deploy?

**A**:
```bash
# App Runner mantiene le versioni precedenti
# Puoi fare rollback manualmente:

# 1. Trova l'immagine precedente in ECR
aws ecr describe-images \
  --repository-name fastapi-docker-example \
  --region eu-west-1

# 2. Aggiorna il servizio con l'immagine precedente
aws apprunner update-service \
  --service-arn <service-arn> \
  --source-configuration "ImageRepository={ImageIdentifier=<previous-image-uri>}"
```

### Q: Come abilito CORS?

**A**: Aggiungi middleware CORS in `main.py`:

```python
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In produzione, specifica domini
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

### Q: Come implemento rate limiting?

**A**: Usa slowapi:

```bash
pip install slowapi

# In main.py
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter

@app.get("/items")
@limiter.limit("10/minute")
async def list_items():
    ...
```

### Q: Posso usare questo in produzione?

**A**: Questo è un progetto didattico. Per produzione, aggiungi:
- Autenticazione (JWT, OAuth)
- Rate limiting
- Input sanitization più rigorosa
- Monitoring avanzato (X-Ray)
- CI/CD pipeline
- Multi-region deployment
- Backup automatici
- Secrets rotation

---

## Comandi Utili per Debug

### Verifica Configurazione Completa

```bash
#!/bin/bash
# check-setup.sh - Verifica che tutto sia configurato

echo "=== Verifica AWS CLI ==="
aws --version
aws sts get-caller-identity

echo "=== Verifica DynamoDB ==="
aws dynamodb describe-table \
  --table-name fastapi-tutorial-items \
  --region eu-west-1 \
  --query 'Table.TableStatus'

echo "=== Verifica Secret ==="
aws secretsmanager describe-secret \
  --secret-id fastapi-tutorial-secrets \
  --region eu-west-1 \
  --query 'Name'

echo "=== Verifica KMS Key ==="
aws kms describe-key \
  --key-id alias/fastapi-tutorial-key \
  --region eu-west-1 \
  --query 'KeyMetadata.KeyState'

echo "=== Verifica IAM Role ==="
aws iam get-role \
  --role-name FastAPITutorialAppRunnerRole \
  --query 'Role.RoleName'

echo "=== Verifica App Runner Service ==="
aws apprunner list-services \
  --region eu-west-1 \
  --query 'ServiceSummaryList[?ServiceName==`fastapi-tutorial-service`].Status'

echo "=== Setup verificato! ==="
```

### Cleanup Completo

```bash
#!/bin/bash
# cleanup.sh - Rimuove tutte le risorse

set -e

echo "⚠️  Questo script eliminerà TUTTE le risorse AWS create per il tutorial"
read -p "Sei sicuro? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Operazione annullata"
    exit 0
fi

# Elimina servizio App Runner
echo "Eliminazione App Runner service..."
SERVICE_ARN=$(aws apprunner list-services --region eu-west-1 \
  --query "ServiceSummaryList[?ServiceName=='fastapi-tutorial-service'].ServiceArn" \
  --output text)
if [ -n "$SERVICE_ARN" ]; then
    aws apprunner delete-service --service-arn $SERVICE_ARN --region eu-west-1
fi

# Elimina tabella DynamoDB
echo "Eliminazione DynamoDB table..."
aws dynamodb delete-table --table-name fastapi-tutorial-items --region eu-west-1 || true

# Elimina secret
echo "Eliminazione Secret..."
aws secretsmanager delete-secret \
  --secret-id fastapi-tutorial-secrets \
  --force-delete-without-recovery \
  --region eu-west-1 || true

# Schedule KMS key deletion
echo "Schedule KMS key deletion..."
KMS_KEY_ID=$(aws kms describe-key --key-id alias/fastapi-tutorial-key \
  --region eu-west-1 --query 'KeyMetadata.KeyId' --output text)
if [ -n "$KMS_KEY_ID" ]; then
    aws kms schedule-key-deletion --key-id $KMS_KEY_ID \
      --pending-window-in-days 7 --region eu-west-1
fi

# Elimina IAM resources
echo "Eliminazione IAM resources..."
aws iam detach-role-policy \
  --role-name FastAPITutorialAppRunnerRole \
  --policy-arn arn:aws:iam::123456789012:policy/FastAPITutorialAppRunnerPolicy || true

aws iam delete-role --role-name FastAPITutorialAppRunnerRole || true
aws iam delete-policy --policy-arn arn:aws:iam::123456789012:policy/FastAPITutorialAppRunnerPolicy || true

echo "✅ Cleanup completato!"
```

---

## Risorse Aggiuntive

- [AWS DynamoDB Troubleshooting](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Programming.Errors.html)
- [AWS Secrets Manager Troubleshooting](https://docs.aws.amazon.com/secretsmanager/latest/userguide/troubleshoot.html)
- [AWS App Runner Troubleshooting](https://docs.aws.amazon.com/apprunner/latest/dg/troubleshoot.html)
- [FastAPI Debugging](https://fastapi.tiangolo.com/tutorial/debugging/)
- [Boto3 Error Handling](https://boto3.amazonaws.com/v1/documentation/api/latest/guide/error-handling.html)

## Supporto

Se hai problemi non coperti in questa guida:

1. Controlla i log di CloudWatch
2. Verifica la configurazione AWS
3. Testa localmente prima di deployare
4. Consulta la documentazione AWS ufficiale
