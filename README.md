# FastAPI AWS Integration Tutorial

[![CI/CD Pipeline](https://github.com/lasalataflavio-hub/fast-api-tutorial/actions/workflows/ci.yml/badge.svg)](https://github.com/lasalataflavio-hub/fast-api-tutorial/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Python 3.11+](https://img.shields.io/badge/python-3.11+-blue.svg)](https://www.python.org/downloads/)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.104+-green.svg)](https://fastapi.tiangolo.com/)
[![AWS](https://img.shields.io/badge/AWS-DynamoDB%20%7C%20Secrets%20Manager%20%7C%20App%20Runner-orange.svg)](https://aws.amazon.com/)

Un progetto didattico completo per imparare l'integrazione di FastAPI con servizi AWS managed: DynamoDB, Secrets Manager, KMS e App Runner.

> 🎓 **Perfetto per**: Corsi universitari, workshop aziendali, autoapprendimento
> 
> ⏱️ **Durata stimata**: 4-6 ore (setup + implementazione + esercizi)
> 
> 📚 **Livello**: Intermedio (richiede conoscenze base di Python e AWS)

## 🎯 Cosa Imparerai

Questo tutorial ti insegna:

- ✅ **Persistenza Dati**: Come collegare FastAPI a DynamoDB per operazioni CRUD
- ✅ **Gestione Secrets**: Come usare AWS Secrets Manager e KMS per proteggere credenziali
- ✅ **Containerizzazione**: Come deployare applicazioni Python su AWS App Runner
- ✅ **IAM Best Practices**: Come usare IAM roles invece di credenziali hardcoded
- ✅ **Logging Strutturato**: Come implementare logging JSON per CloudWatch
- ✅ **Error Handling**: Come gestire errori AWS in modo robusto
- ✅ **API Design**: Come costruire API REST ben documentate con FastAPI

## 🏗️ Architettura

```
┌─────────────┐
│   Client    │
└──────┬──────┘
       │ HTTPS
       ▼
┌─────────────────────────────┐
│    AWS App Runner           │
│  ┌───────────────────────┐  │
│  │  FastAPI Container    │  │
│  │  - REST API           │  │
│  │  - DynamoDB Client    │  │
│  │  - Secrets Client     │  │
│  └───────────────────────┘  │
└─────────────────────────────┘
       │         │         │
       ▼         ▼         ▼
  DynamoDB   Secrets   CloudWatch
             Manager
               │
               ▼
            KMS Key
```

## 📋 Prerequisiti

- **Account AWS** con permessi per creare risorse
- **AWS CLI** installato e configurato con profile 'plug' (`aws configure --profile plug`)
- **Docker** installato
- **Python 3.11+** (per sviluppo locale)
- Conoscenza base di:
  - Python e FastAPI
  - REST APIs
  - Docker
  - AWS (concetti base)

## 🚀 Quick Start

### 1. Clone e Setup Locale

```bash
# Clone del repository
git clone https://github.com/lasalataflavio-hub/fast-api-tutorial.git
cd fastapi-aws-tutorial

# Crea ambiente virtuale
python -m venv venv
source venv/bin/activate  # Su Windows: venv\Scripts\activate

# Installa dipendenze
pip install -r requirements.txt

# Copia file di configurazione
cp .env.example .env.local
```

**⚠️ IMPORTANTE**: Modifica `.env.local` con i tuoi dati AWS reali prima di procedere!

### 2. Setup Infrastruttura AWS

**Importante**: Configura il profile AWS 'plug' e il tuo Account ID:

```bash
# 1. Configura il profile plug
aws configure --profile plug

# 2. Crea file di configurazione locale
cp .env.local.example .env.local

# 3. Modifica .env.local con il tuo AWS Account ID
# Apri .env.local e sostituisci 123456789012 con il tuo Account ID
nano .env.local  # oppure usa il tuo editor preferito

# 4. Verifica
aws sts get-caller-identity --profile plug
```

**Opzione A: Setup Automatico (Consigliato) 🚀**

```bash
# Esegui lo script di setup (crea tutto automaticamente)
./setup-aws.sh
```

Lo script caricherà automaticamente la configurazione da `.env.local`.

Lo script creerà automaticamente:
- ✅ KMS Key per encryption
- ✅ Secret in Secrets Manager
- ✅ Tabella DynamoDB
- ✅ IAM Role e Policy
- ✅ Repository ECR
- ✅ Servizio App Runner
- ✅ Build e deploy della prima immagine

**Opzione B: Setup Manuale**

Segui la guida completa in [docs/SETUP.md](docs/SETUP.md) per creare le risorse manualmente.

### 3. Deploy su AWS

```bash
# Build immagine Docker
docker build -t fastapi-docker-example:latest .

# Login a ECR
aws ecr get-login-password --region eu-west-1 | \
  docker login --username AWS --password-stdin \
  ${AWS_ACCOUNT_ID}.dkr.ecr.eu-west-1.amazonaws.com

# Tag e push
docker tag fastapi-docker-example:latest \
  ${AWS_ACCOUNT_ID}.dkr.ecr.eu-west-1.amazonaws.com/fastapi-docker-example:latest

docker push ${AWS_ACCOUNT_ID}.dkr.ecr.eu-west-1.amazonaws.com/fastapi-docker-example:latest

# App Runner aggiornerà automaticamente il servizio
```

### 4. Test dell'API

```bash
# Ottieni URL del servizio
export SERVICE_URL=$(aws apprunner describe-service \
  --service-arn <service-arn> \
  --region eu-west-1 \
  --profile plug \
  --query 'Service.ServiceUrl' \
  --output text)

# Test health check
curl https://${SERVICE_URL}/health

# Crea un item
curl -X POST https://${SERVICE_URL}/items \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Laptop Dell XPS",
    "description": "Laptop per sviluppo",
    "tags": ["elettronica", "computer"]
  }'

# Lista items
curl https://${SERVICE_URL}/items

# Documentazione interattiva
open https://${SERVICE_URL}/docs
```

## 📚 Documentazione

- **[AWS_PROFILE_SETUP.md](AWS_PROFILE_SETUP.md)** - Setup profile AWS 'plug' (INIZIA DA QUI!)
- **[SETUP.md](docs/SETUP.md)** - Guida completa setup AWS con comandi step-by-step
- **[ARCHITECTURE.md](docs/ARCHITECTURE.md)** - Spiegazione dettagliata dell'architettura e design decisions
- **[CODE_GUIDE.md](docs/CODE_GUIDE.md)** - Walkthrough del codice con esempi e pattern
- **[TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** - Risoluzione problemi comuni e FAQ

## 🔌 API Endpoints

### Core Endpoints

- `GET /` - Welcome message con stato sistema
- `GET /health` - Health check (verifica connessione DynamoDB)
- `GET /config` - Configurazione applicazione (valori safe)
- `GET /docs` - Documentazione interattiva Swagger UI

### Items Management

- `POST /items` - Crea nuovo item
- `GET /items` - Lista tutti gli items
- `GET /items/{item_id}` - Recupera item specifico
- `DELETE /items/{item_id}` - Elimina item

### Esempio Request/Response

**POST /items**
```json
// Request
{
  "name": "Laptop Dell XPS",
  "description": "Laptop per sviluppo con 16GB RAM",
  "tags": ["elettronica", "computer", "lavoro"]
}

// Response (201 Created)
{
  "item_id": "123e4567-e89b-12d3-a456-426614174000",
  "name": "Laptop Dell XPS",
  "description": "Laptop per sviluppo con 16GB RAM",
  "tags": ["elettronica", "computer", "lavoro"],
  "created_at": "2025-02-12T10:30:00.000000",
  "updated_at": "2025-02-12T10:30:00.000000"
}
```

## 🛠️ Sviluppo Locale

### Run con Uvicorn

```bash
# Opzione 1: Senza AWS (solo per vedere la documentazione)
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Opzione 2: Con AWS configurato (per testare funzionalità complete)
export AWS_PROFILE=plug
export AWS_REGION=eu-west-1
export DYNAMODB_TABLE_NAME=fastapi-tutorial-items
export SECRET_NAME=fastapi-tutorial-secrets
export DEBUG=true

uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Apri browser
open http://localhost:8000/docs
```

**Nota**: L'applicazione parte anche senza credenziali AWS. Vedrai warning nei log ma potrai accedere a `/docs` per vedere la documentazione API.

### Run con Docker

```bash
# Build
docker build -t fastapi-tutorial .

# Run
docker run -p 8000:8000 \
  -e AWS_REGION=eu-west-1 \
  -e DYNAMODB_TABLE_NAME=fastapi-tutorial-items \
  -e SECRET_NAME=fastapi-tutorial-secrets \
  fastapi-tutorial

# Test
curl http://localhost:8000/health
```

## 📁 Struttura del Progetto

```
.
├── app/
│   ├── main.py              # FastAPI app con endpoints
│   ├── config.py            # Configurazione (Pydantic Settings)
│   ├── database.py          # DynamoDB client (CRUD operations)
│   ├── secrets.py           # Secrets Manager client
│   ├── models.py            # Modelli Pydantic (request/response)
│   ├── logging_config.py    # Logging strutturato JSON
│   └── middleware.py        # Middleware per logging richieste
├── docs/
│   ├── SETUP.md            # Guida setup AWS
│   ├── ARCHITECTURE.md     # Documentazione architettura
│   ├── CODE_GUIDE.md       # Guida al codice
│   └── TROUBLESHOOTING.md  # Troubleshooting e FAQ
├── requirements.txt         # Dipendenze Python
├── Dockerfile              # Container definition
├── .env.example            # Template variabili d'ambiente
├── .dockerignore           # File esclusi da build
└── README.md               # Questo file
```

## 🔐 Sicurezza

Questo progetto implementa AWS security best practices:

- ✅ **No Hardcoded Credentials**: Usa IAM roles per autenticazione
- ✅ **Least Privilege**: IAM policy con permessi minimi necessari
- ✅ **Encryption at Rest**: DynamoDB e Secrets Manager criptati di default
- ✅ **Encryption in Transit**: HTTPS enforced da App Runner
- ✅ **Secrets Management**: Credenziali in Secrets Manager, criptate con KMS
- ✅ **Secure Logging**: Redaction automatica di valori sensibili nei log
- ✅ **Input Validation**: Pydantic valida tutti gli input

## 💰 Costi Stimati

Per un ambiente di test/tutorial con basso traffico:

| Servizio | Costo Mensile Stimato |
|----------|----------------------|
| DynamoDB (on-demand) | $1-5 |
| Secrets Manager | $0.40 per secret |
| KMS | $1 + $0.03/10k requests |
| App Runner | $5-20 |
| CloudWatch Logs | $0.50 per GB |
| **Totale** | **~$8-27/mese** |

💡 **Tip**: Usa AWS Free Tier quando possibile e elimina le risorse quando non servono.

## 🧪 Testing

### Test Manuali

```bash
# Health check
curl http://localhost:8000/health

# Crea item
curl -X POST http://localhost:8000/items \
  -H "Content-Type: application/json" \
  -d '{"name":"Test","description":"Test item","tags":["test"]}'

# Lista items
curl http://localhost:8000/items

# Get item specifico
curl http://localhost:8000/items/<item-id>

# Delete item
curl -X DELETE http://localhost:8000/items/<item-id>
```

### Documentazione Interattiva

FastAPI genera automaticamente documentazione interattiva:

- **Swagger UI**: `http://localhost:8000/docs`
- **ReDoc**: `http://localhost:8000/redoc`

Puoi testare tutti gli endpoints direttamente dal browser!

## 🎓 Esercizi per Studenti

### Livello Base
1. Aggiungi un campo `quantity` al modello Item
2. Implementa un endpoint `PATCH /items/{item_id}` per aggiornare items
3. Aggiungi validazione: `quantity` deve essere >= 0

### Livello Intermedio
4. Implementa paginazione per `GET /items` (usa DynamoDB LastEvaluatedKey)
5. Aggiungi filtro per tag: `GET /items?tag=elettronica`
6. Implementa soft delete (campo `deleted_at` invece di eliminare)

### Livello Avanzato
7. Aggiungi autenticazione con API keys (usa il secret da Secrets Manager)
8. Implementa rate limiting (es. 100 requests/minuto per IP)
9. Aggiungi caching con Redis/ElastiCache
10. Implementa full-text search con OpenSearch

## 🔧 Troubleshooting

Problemi comuni e soluzioni:

### "Table not found"
```bash
# Verifica che la tabella esista
aws dynamodb describe-table --table-name fastapi-tutorial-items --region eu-west-1
```

### "AccessDeniedException"
```bash
# Verifica IAM permissions del role
aws iam list-attached-role-policies --role-name FastAPITutorialAppRunnerRole
```

### "Secret not found"
```bash
# Verifica che il secret esista
aws secretsmanager describe-secret --secret-id fastapi-tutorial-secrets --region eu-west-1
```

Per troubleshooting dettagliato, consulta [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

## 📖 Risorse Aggiuntive

### Documentazione Ufficiale
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [AWS DynamoDB Developer Guide](https://docs.aws.amazon.com/dynamodb/)
- [AWS Secrets Manager User Guide](https://docs.aws.amazon.com/secretsmanager/)
- [AWS App Runner Developer Guide](https://docs.aws.amazon.com/apprunner/)
- [Boto3 Documentation](https://boto3.amazonaws.com/v1/documentation/api/latest/index.html)

### Tutorial e Guide
- [FastAPI Best Practices](https://github.com/zhanymkanov/fastapi-best-practices)
- [AWS DynamoDB Best Practices](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/best-practices.html)
- [12-Factor App Methodology](https://12factor.net/)

## 🤝 Contribuire

Questo è un progetto didattico open source! I contributi sono benvenuti. 

**Come contribuire:**
1. 🍴 Fork del repository
2. 🌿 Crea un branch per la tua feature (`git checkout -b feature/amazing-feature`)
3. ✅ Commit delle modifiche (`git commit -m 'Add amazing feature'`)
4. 📤 Push al branch (`git push origin feature/amazing-feature`)
5. 🔄 Apri una Pull Request

Leggi [CONTRIBUTING.md](CONTRIBUTING.md) per linee guida dettagliate.

### 🎯 Aree dove Contribuire

- 📚 Miglioramenti alla documentazione
- 🐛 Correzioni di bug
- ✨ Nuovi esercizi per studenti
- 🔐 Miglioramenti alla sicurezza
- 🌍 Traduzioni in altre lingue

## 📝 License

Questo progetto è rilasciato sotto licenza MIT - vedi il file LICENSE per dettagli.

## 👨‍🏫 Per Docenti

Questo progetto è ideale per:
- Corsi di Cloud Computing
- Corsi di Sviluppo Web Backend
- Workshop su AWS
- Progetti di laboratorio

**Durata stimata**: 4-6 ore (setup + implementazione + esercizi)

**Prerequisiti studenti**:
- Python base
- Concetti REST API
- Familiarità con terminal/CLI

## 🙋 Supporto e Community

- 📖 **Documentazione**: Leggi la [documentazione completa](docs/)
- 🐛 **Bug o Problemi**: Consulta [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) o apri una [Issue](../../issues)
- 💬 **Domande**: Usa le [GitHub Discussions](../../discussions) per domande generali
- 🚀 **Feature Request**: Apri una [Issue](../../issues) con label "enhancement"

### 📊 Statistiche Progetto

![GitHub stars](https://img.shields.io/github/stars/lasalataflavio-hub/fast-api-tutorial?style=social)
![GitHub forks](https://img.shields.io/github/forks/lasalataflavio-hub/fast-api-tutorial?style=social)
![GitHub issues](https://img.shields.io/github/issues/lasalataflavio-hub/fast-api-tutorial)
![GitHub pull requests](https://img.shields.io/github/issues-pr/lasalataflavio-hub/fast-api-tutorial)

---

**Buon apprendimento! 🚀**

Made with ❤️ for learning AWS + FastAPI
