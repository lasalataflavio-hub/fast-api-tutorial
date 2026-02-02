# Quick Start Guide

Guida rapida per iniziare subito con il progetto.

## 🚀 Setup in 5 Minuti (Locale)

### 1. Installa Dipendenze

```bash
# Crea virtual environment
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# Installa requirements
pip install -r requirements.txt
```

### 2. Test Locale (Senza AWS)

```bash
# Test con mock clients
python test_local.py
```

Se vedi "Tutti i test passati! ✓" sei pronto per il deploy!

### 3. Run Locale (Senza Credenziali AWS)

```bash
# Run server (funziona anche senza AWS configurato)
uvicorn app.main:app --reload --port 8000
```

**Nota**: L'applicazione parte anche senza credenziali AWS configurate. Vedrai dei warning nei log ma il server funzionerà. Gli endpoint che richiedono AWS (come `/items`) non funzioneranno, ma `/` e `/docs` saranno accessibili.

### 3b. Run Locale (Con AWS Configurato)

Se hai configurato AWS e vuoi testare con i servizi reali:

```bash
# Configura variabili
export AWS_PROFILE=plug
export AWS_REGION=eu-west-1
export DYNAMODB_TABLE_NAME=fastapi-tutorial-items
export SECRET_NAME=fastapi-tutorial-secrets

# Run server
uvicorn app.main:app --reload --port 8000
```

### 4. Test API

Apri browser: http://localhost:8000/docs

Oppure usa curl:

```bash
# Health check
curl http://localhost:8000/health

# Crea item
curl -X POST http://localhost:8000/items \
  -H "Content-Type: application/json" \
  -d '{"name":"Test","description":"Item di test","tags":["test"]}'
```

## ☁️ Deploy su AWS (Completo)

### Prerequisiti

- Account AWS
- AWS CLI configurato con profile 'plug' (`aws configure --profile plug`)
- Docker installato

### Step 1: Setup Iniziale (UNA VOLTA)

```bash
# Configura profile AWS
aws configure --profile plug

# Esegui setup automatico
./setup-aws.sh
```

Lo script `setup-aws.sh` creerà automaticamente:
- ✅ KMS Key
- ✅ Secret in Secrets Manager
- ✅ Tabella DynamoDB
- ✅ IAM Role e Policy
- ✅ Repository ECR
- ✅ Servizio App Runner
- ✅ Prima immagine Docker

**Tempo stimato**: 5-10 minuti

### Step 2: Deploy Successivi

Dopo il setup iniziale, per aggiornare l'applicazione:

```bash
# Deploy automatico
./deploy.sh
```

Lo script fa:
1. Build Docker image
2. Push su ECR
3. App Runner si aggiorna automaticamente

### Step 3: Test su AWS

```bash
# Ottieni URL del servizio
export SERVICE_URL=$(aws apprunner describe-service \
  --service-arn <your-service-arn> \
  --region eu-west-1 \
  --query 'Service.ServiceUrl' \
  --output text)

# Test
curl https://${SERVICE_URL}/health
```

## 📚 Documentazione

- **Setup AWS**: [docs/SETUP.md](docs/SETUP.md) - Guida completa setup
- **Architettura**: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) - Come funziona
- **Code Guide**: [docs/CODE_GUIDE.md](docs/CODE_GUIDE.md) - Walkthrough codice
- **Troubleshooting**: [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) - Problemi comuni

## 🎯 Cosa Fare Dopo

### Per Principianti

1. Esplora la documentazione interattiva: `/docs`
2. Prova tutti gli endpoint con curl o Postman
3. Leggi il codice in `app/` per capire come funziona
4. Modifica un endpoint e fai redeploy

### Per Intermedi

1. Aggiungi un campo al modello Item
2. Implementa endpoint PATCH per aggiornare items
3. Aggiungi paginazione a GET /items
4. Implementa filtri per tag

### Per Avanzati

1. Aggiungi autenticazione con JWT
2. Implementa rate limiting
3. Aggiungi caching con Redis
4. Implementa CI/CD con GitHub Actions
5. Aggiungi monitoring con X-Ray

## 🔧 Comandi Utili

```bash
# Setup iniziale AWS (UNA VOLTA)
./setup-aws.sh

# Test locale con mock
python test_local.py

# Run server locale
uvicorn app.main:app --reload

# Test API interattivi
./examples.sh

# Deploy su AWS (aggiornamenti)
./deploy.sh

# Elimina tutte le risorse AWS
./cleanup-aws.sh

# Visualizza log AWS
aws logs tail /aws/apprunner/<service-name>/service --follow --profile plug

# Verifica setup AWS
aws dynamodb describe-table --table-name fastapi-tutorial-items --profile plug
aws secretsmanager describe-secret --secret-id fastapi-tutorial-secrets --profile plug
```

## ❓ Problemi?

1. **Errore import**: Verifica che `app/__init__.py` esista
2. **Errore AWS**: Verifica `aws configure --profile plug` e IAM permissions
3. **Profile AWS**: Assicurati di aver esportato `export AWS_PROFILE=plug`
4. **Errore Docker**: Verifica che Docker sia in running
5. **Altri problemi**: Consulta [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)

## 💡 Tips

- Usa `/docs` per testare API interattivamente
- Controlla sempre i log per debugging
- Testa locale prima di deployare su AWS
- Usa `DEBUG=true` per log dettagliati
- Elimina risorse AWS quando non servono per risparmiare

## 📖 Prossimi Passi

1. ✅ Setup locale e test
2. ✅ Capire l'architettura
3. ✅ Setup AWS
4. ✅ Deploy e test su AWS
5. 🎓 Esercizi e estensioni

Buon apprendimento! 🚀
