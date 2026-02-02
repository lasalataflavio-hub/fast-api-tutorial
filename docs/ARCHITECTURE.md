# Architettura - FastAPI AWS Tutorial

Questo documento spiega l'architettura dell'applicazione e le scelte di design.

## Overview

L'applicazione è una API REST costruita con FastAPI che dimostra l'integrazione con servizi AWS managed:

- **DynamoDB**: Database NoSQL serverless per persistenza dati
- **Secrets Manager**: Gestione sicura di credenziali e secrets
- **KMS**: Encryption delle variabili sensibili
- **App Runner**: Hosting containerizzato dell'applicazione
- **CloudWatch**: Logging e monitoring

## Diagramma Architettura

```
┌─────────────┐
│   Studente  │
│   /Utente   │
└──────┬──────┘
       │ HTTPS
       ▼
┌─────────────────────────────────────────┐
│         AWS App Runner                  │
│  ┌───────────────────────────────────┐  │
│  │     FastAPI Container             │  │
│  │  ┌─────────────────────────────┐  │  │
│  │  │  FastAPI Application        │  │  │
│  │  │  - Endpoints REST           │  │  │
│  │  │  - Validation (Pydantic)    │  │  │
│  │  │  - Error Handling           │  │  │
│  │  └─────────────────────────────┘  │  │
│  │  ┌─────────────────────────────┐  │  │
│  │  │  DynamoDB Client            │  │  │
│  │  │  - CRUD Operations          │  │  │
│  │  │  - Health Check             │  │  │
│  │  └─────────────────────────────┘  │  │
│  │  ┌─────────────────────────────┐  │  │
│  │  │  Secrets Client             │  │  │
│  │  │  - Get Secrets              │  │  │
│  │  │  - Caching                  │  │  │
│  │  └─────────────────────────────┘  │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
       │              │              │
       │ IAM Role     │ IAM Role     │ Logs
       ▼              ▼              ▼
┌─────────────┐ ┌──────────────┐ ┌──────────────┐
│  DynamoDB   │ │   Secrets    │ │  CloudWatch  │
│   Table     │ │   Manager    │ │    Logs      │
└─────────────┘ └──────┬───────┘ └──────────────┘
                       │
                       │ Encrypted with
                       ▼
                ┌──────────────┐
                │   KMS Key    │
                └──────────────┘
```

## Componenti Principali

### 1. FastAPI Application (`app/main.py`)

Il cuore dell'applicazione. Gestisce:

- **Lifecycle Management**: Inizializzazione dei client AWS all'avvio
- **Routing**: Definizione degli endpoint REST
- **Validation**: Validazione automatica input/output con Pydantic
- **Error Handling**: Gestione centralizzata degli errori
- **Documentation**: Generazione automatica OpenAPI/Swagger

**Pattern utilizzati**:
- Dependency Injection (implicita con FastAPI)
- Lifespan Events per inizializzazione
- Exception Handlers per errori consistenti

### 2. DynamoDB Client (`app/database.py`)

Astrae le operazioni sul database.

**Responsabilità**:
- CRUD operations (Create, Read, Update, Delete)
- Generazione UUID per item IDs
- Health check della connessione
- Error handling specifico DynamoDB

**Design Decisions**:
- Usa `boto3.resource` invece di `client` per API più semplice
- Timestamp automatici (created_at, updated_at)
- Eccezione custom `ItemNotFoundException` per 404

**Esempio di flusso - Creazione Item**:
```
1. Client chiama create_item(data)
2. Genera UUID univoco
3. Aggiunge timestamp
4. Scrive su DynamoDB con put_item()
5. Ritorna item_id
6. Se errore → ClientError con logging
```

### 3. Secrets Manager Client (`app/secrets.py`)

Gestisce il recupero di secrets da AWS.

**Responsabilità**:#
- Recupero secrets da Secrets Manager
- Parsing JSON dei secrets
- Caching per ridurre chiamate API
- Error handling per secrets non trovati

**Design Decisions**:
- Cache in-memory dei secrets (riduce latenza e costi)
- Supporto solo per secrets JSON (non binary)
- Logging senza esporre valori sensibili

**Flusso di recupero secret**:
```
1. Client chiama get_secret(name)
2. Controlla cache locale
3. Se non in cache → chiama AWS Secrets Manager
4. AWS decripta automaticamente con KMS
5. Parse JSON
6. Salva in cache
7. Ritorna dizionario
```

### 4. Configuration Manager (`app/config.py`)

Centralizza la configurazione dell'applicazione.

**Responsabilità**:
- Caricamento variabili d'ambiente
- Validazione configurazione con Pydantic
- Metodo `safe_dict()` per logging sicuro

**Design Decisions**:
- Usa Pydantic Settings per type safety
- Valori di default per sviluppo locale
- Separazione tra config pubblica e secrets

### 5. Data Models (`app/models.py`)

Definisce i contratti API con Pydantic.

**Modelli principali**:
- `ItemCreate`: Input per creazione item
- `ItemResponse`: Output con item completo
- `HealthResponse`: Stato salute applicazione
- `ConfigResponse`: Configurazione safe
- `ErrorResponse`: Formato errori consistente

**Vantaggi**:
- Validazione automatica input
- Documentazione OpenAPI automatica
- Type hints per IDE
- Serializzazione/deserializzazione automatica

### 6. Logging (`app/logging_config.py`)

Logging strutturato in formato JSON.

**Caratteristiche**:
- Output JSON per CloudWatch Logs Insights
- Redaction automatica di valori sensibili
- Livelli di log configurabili
- Metadata aggiuntivi (timestamp, module, function)

**Esempio log JSON**:
```json
{
  "timestamp": "2025-02-12T10:30:00.123Z",
  "level": "INFO",
  "logger": "app.database",
  "module": "database",
  "function": "create_item",
  "message": "Item creato con successo",
  "item_id": "123e4567-e89b-12d3-a456-426614174000"
}
```

### 7. Middleware (`app/middleware.py`)

Logging automatico delle richieste HTTP.

**Funzionalità**:
- Log di ogni richiesta ricevuta
- Misurazione durata richiesta
- Log di risposta con status code
- Log di errori con stack trace

## Flussi di Dati Principali

### Flusso 1: Startup dell'Applicazione

```
1. App Runner avvia container Docker
2. FastAPI inizializza (lifespan event)
3. Setup logging strutturato
4. Inizializza SecretsClient
5. Recupera secrets da Secrets Manager
   - AWS decripta con KMS automaticamente
6. Carica secrets in Settings
7. Inizializza DynamoDBClient
8. Esegue health check DynamoDB
9. Applicazione pronta per richieste
```

### Flusso 2: Creazione di un Item

```
Client Request:
POST /items
{
  "name": "Laptop",
  "description": "Dell XPS",
  "tags": ["elettronica"]
}

↓

1. Middleware logga richiesta
2. FastAPI valida input con ItemCreate model
3. Endpoint create_item() chiamato
4. DynamoDBClient.create_item():
   - Genera UUID
   - Aggiunge timestamp
   - Scrive su DynamoDB
5. Recupera item appena creato
6. Converte a ItemResponse model
7. FastAPI serializza a JSON
8. Middleware logga risposta
9. Ritorna HTTP 201 con item

↓

Client Response:
{
  "item_id": "uuid...",
  "name": "Laptop",
  "description": "Dell XPS",
  "tags": ["elettronica"],
  "created_at": "2025-02-12T10:30:00",
  "updated_at": "2025-02-12T10:30:00"
}
```

### Flusso 3: Health Check

```
Client Request:
GET /health

↓

1. Endpoint health_check() chiamato
2. DynamoDBClient.health_check():
   - Chiama describe_table()
   - Verifica status = ACTIVE
3. Costruisce HealthResponse
4. Ritorna HTTP 200

↓

Client Response:
{
  "status": "healthy",
  "database": "connected",
  "timestamp": "2025-02-12T10:30:00"
}
```

## Sicurezza

### Autenticazione e Autorizzazione

**IAM Roles**:
- App Runner usa un IAM role (non credenziali hardcoded)
- Principle of Least Privilege: solo permessi necessari
- Separazione tra access role e instance role

**Encryption**:
- **At Rest**: DynamoDB e Secrets Manager usano encryption di default
- **In Transit**: HTTPS enforced da App Runner
- **Secrets**: Criptati con KMS customer managed key

### Best Practices Implementate

1. **No Hardcoded Credentials**: Tutto tramite IAM roles
2. **Secrets Rotation**: Possibile configurare rotation automatica
3. **Logging Sicuro**: Redaction automatica di valori sensibili
4. **Input Validation**: Pydantic valida tutti gli input
5. **Error Messages**: Non espongono dettagli interni

## Scalabilità

### DynamoDB

- **Billing Mode**: PAY_PER_REQUEST (on-demand)
- **Auto-scaling**: Gestito automaticamente da AWS
- **Performance**: Single-digit millisecond latency

### App Runner

- **Auto-scaling**: Basato su CPU e richieste
- **Min/Max Instances**: Configurabile
- **Health Checks**: Automatic restart su failure

### Caching

- **Secrets**: Cache in-memory per ridurre chiamate API
- **Future**: Possibile aggiungere Redis/ElastiCache

## Monitoring e Observability

### CloudWatch Logs

- Log strutturati in JSON
- Filtri e query con CloudWatch Logs Insights
- Retention configurabile

**Query di esempio**:
```
# Trova tutti gli errori
fields @timestamp, level, message, error
| filter level = "ERROR"
| sort @timestamp desc

# Analizza latenza richieste
fields @timestamp, duration_ms, path, status_code
| filter path = "/items"
| stats avg(duration_ms), max(duration_ms), count()
```

### Metriche

App Runner fornisce metriche automatiche:
- Request count
- Response time
- Error rate
- CPU/Memory utilization

### Health Checks

- Endpoint `/health` verifica connessione DynamoDB
- App Runner usa health check per auto-healing
- Configurabile: interval, timeout, thresholds

## Costi

Stima costi mensili per ambiente di test/tutorial:

- **DynamoDB**: ~$1-5 (on-demand, basso traffico)
- **Secrets Manager**: ~$0.40 per secret
- **KMS**: ~$1 per key + $0.03 per 10k requests
- **App Runner**: ~$5-20 (dipende da utilizzo)
- **CloudWatch Logs**: ~$0.50 per GB

**Totale stimato**: $8-27/mese per ambiente didattico

## Estensioni Future

Possibili miglioramenti per studenti avanzati:

1. **Authentication**: Aggiungere JWT o API keys
2. **Rate Limiting**: Protezione da abuse
3. **Caching**: Redis per query frequenti
4. **Search**: OpenSearch per ricerca full-text
5. **Events**: EventBridge per event-driven architecture
6. **CI/CD**: GitHub Actions per deploy automatico
7. **Multi-region**: Replicazione DynamoDB global tables
8. **Monitoring**: X-Ray per distributed tracing

## Riferimenti

- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [AWS DynamoDB Best Practices](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/best-practices.html)
- [AWS Secrets Manager](https://docs.aws.amazon.com/secretsmanager/)
- [AWS App Runner](https://docs.aws.amazon.com/apprunner/)
- [Pydantic Documentation](https://docs.pydantic.dev/)
