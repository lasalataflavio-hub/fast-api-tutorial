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
- **AWS CLI** installato e configurato (`aws configure`)
- **Docker** installato
- **Python 3.11+** (per sviluppo locale)
- Conoscenza base di:
  - Python e FastAPI
  - REST APIs
  - Docker
  - AWS (concetti base)

## 🚀 Quick Start

### Opzione 1: Test Rapido con Docker (Consigliato)

Se vuoi solo vedere il progetto funzionare senza installare Python:

```bash
# 1. Clone del repository
git clone https://github.com/lasalataflavio-hub/fast-api-tutorial.git
cd fast-api-tutorial

# 2. Build Docker image
docker build -t fastapi-tutorial .

# 3. Run (senza AWS - solo per vedere la documentazione)
docker run -p 8000:8000 fastapi-tutorial

# 4. Apri browser
open http://localhost:8000/docs
```

L'app parte anche senza AWS configurato. Vedrai la documentazione interattiva su `/docs`.

### Opzione 2: Setup Completo con AWS

Per usare tutte le funzionalità (DynamoDB, Secrets Manager, ecc.):

#### 1. Clone e Dipendenze

```bash
git clone https://github.com/lasalataflavio-hub/fast-api-tutorial.git
cd fast-api-tutorial

# Opzionale: crea ambiente virtuale Python
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
```

#### 2. Configura AWS CLI

```bash
# Configura le tue credenziali AWS
aws configure --profile tuo-profile

# Verifica configurazione e ottieni il tuo Account ID
aws sts get-caller-identity --profile tuo-profile
```

#### 3. Crea File .env.local

**IMPORTANTE**: Il file `.env.local` non è su Git per sicurezza. Devi crearlo:

```bash
# Copia il template
cp .env.example .env.local
```

Modifica `.env.local` con i tuoi dati AWS:

```bash
AWS_PROFILE=tuo-profile          # Il profile che hai configurato
AWS_REGION=eu-west-1             # La tua region AWS
AWS_ACCOUNT_ID=123456789012      # Il tuo Account ID (dal comando sopra)
```

#### 4. Setup Infrastruttura AWS

**Windows (PowerShell)**:
```powershell
powershell -ExecutionPolicy Bypass -File setup-aws.ps1
```

**Linux/macOS (Bash)**:
```bash
chmod +x setup-aws.sh
./setup-aws.sh
```

Lo script crea automaticamente tutte le risorse AWS (5-10 minuti).

#### 5. Test dell'API

Dopo il deployment, lo script mostrerà l'URL del servizio. Testa l'API:

```bash
# Sostituisci con il tuo service URL
SERVICE_URL="tuo-service-url.awsapprunner.com"

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

### Test Veloce (senza AWS)

```bash
# Con Docker
docker run -p 8000:8000 fastapi-tutorial
open http://localhost:8000/docs

# Oppure con Python (se hai installato le dipendenze)
uvicorn app.main:app --reload
open http://localhost:8000/docs
```

L'app parte anche senza AWS. Vedrai warning nei log ma potrai accedere alla documentazione.

### Test Completo (con AWS)

```bash
# Configura variabili d'ambiente
export AWS_PROFILE=tuo-profile
export AWS_REGION=eu-west-1
export DYNAMODB_TABLE_NAME=fastapi-tutorial-items
export SECRET_NAME=fastapi-tutorial-secrets

# Run
uvicorn app.main:app --reload

# Test
curl http://localhost:8000/health
curl http://localhost:8000/items
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

### Problemi Comuni

#### 1. PowerShell blocca l'esecuzione dello script (Windows)

**Errore**:
```
.\setup-aws.ps1 : Impossibile caricare il file. L'esecuzione di script è disabilitata.
```

**Soluzione**:
```powershell
# Usa questo comando invece
powershell -ExecutionPolicy Bypass -File setup-aws.ps1
```

#### 2. AWS_ACCOUNT_ID non trovato

**Errore**:
```
ERRORE: AWS_ACCOUNT_ID non trovato in .env.local
```

**Soluzione**:
```bash
# 1. Ottieni il tuo Account ID
aws sts get-caller-identity --profile tuo-profile --query Account --output text

# 2. Aggiungi al file .env.local
echo "AWS_ACCOUNT_ID=123456789012" >> .env.local
```

#### 3. Table not found

**Errore**:
```
Table not found: fastapi-tutorial-items
```

**Soluzione**:
```bash
# Verifica che la tabella esista
aws dynamodb describe-table --table-name fastapi-tutorial-items --region eu-west-1 --profile tuo-profile

# Se non esiste, esegui di nuovo il setup
powershell -ExecutionPolicy Bypass -File setup-aws.ps1
```

#### 4. AccessDeniedException

**Errore**:
```
AccessDeniedException: User is not authorized to perform...
```

**Soluzione**:
```bash
# Verifica IAM permissions del tuo utente
aws iam list-attached-user-policies --user-name tuo-username

# Assicurati di avere i permessi per:
# - DynamoDB
# - Secrets Manager
# - KMS
# - ECR
# - App Runner
# - IAM
```

#### 5. Secret not found

**Errore**:
```
Secret not found: fastapi-tutorial-secrets
```

**Soluzione**:
```bash
# Verifica che il secret esista
aws secretsmanager describe-secret --secret-id fastapi-tutorial-secrets --region eu-west-1 --profile tuo-profile

# Se non esiste, esegui di nuovo il setup
```

### 🗑️ Eliminare Tutte le Risorse (Cleanup)

Quando hai finito di usare il progetto, elimina tutte le risorse per evitare costi:

#### Su Windows (PowerShell):

```powershell
# Esegui lo script di cleanup
powershell -ExecutionPolicy Bypass -File cleanup-aws.ps1

# Lo script chiederà conferma
# Digita 'DELETE' per confermare l'eliminazione
```

#### Su Linux/macOS (Bash):

```bash
# Rendi eseguibile lo script
chmod +x cleanup-aws.sh

# Esegui lo script
./cleanup-aws.sh

# Lo script chiederà conferma
# Digita 'DELETE' per confermare l'eliminazione
```

**Cosa viene eliminato**:
- ✅ App Runner Service
- ✅ ECR Repository (con tutte le immagini)
- ✅ DynamoDB Table (con tutti i dati)
- ✅ Secrets Manager Secret
- ✅ IAM Roles e Policies
- ⏳ KMS Key (scheduled deletion dopo 7 giorni)

**ATTENZIONE**: L'operazione è IRREVERSIBILE! Tutti i dati saranno persi.

**Costi dopo cleanup**: €0/mese (la KMS Key sarà eliminata automaticamente dopo 7 giorni)

### 📝 Ciclo Completo di Sviluppo

```bash
# 1. Setup iniziale
powershell -ExecutionPolicy Bypass -File setup-aws.ps1

# 2. Sviluppo e test locale
uvicorn app.main:app --reload

# 3. Deploy modifiche
./deploy.sh  # o deploy.ps1 su Windows

# 4. Test in produzione
curl https://tuo-service-url.awsapprunner.com/health

# 5. Cleanup quando finito
powershell -ExecutionPolicy Bypass -File cleanup-aws.ps1
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
