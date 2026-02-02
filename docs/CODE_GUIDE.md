# Code Walkthrough - FastAPI AWS Tutorial

Questa guida ti accompagna attraverso il codice, spiegando ogni componente e come interagiscono.

## Struttura del Progetto

```
.
├── app/
│   ├── __init__.py
│   ├── main.py              # Applicazione FastAPI principale
│   ├── config.py            # Configurazione centralizzata
│   ├── database.py          # Client DynamoDB
│   ├── secrets.py           # Client Secrets Manager
│   ├── models.py            # Modelli Pydantic
│   ├── logging_config.py    # Setup logging strutturato
│   └── middleware.py        # Middleware HTTP
├── docs/
│   ├── SETUP.md            # Guida setup AWS
│   ├── ARCHITECTURE.md     # Documentazione architettura
│   ├── CODE_GUIDE.md       # Questa guida
│   └── TROUBLESHOOTING.md  # Risoluzione problemi
├── requirements.txt         # Dipendenze Python
├── Dockerfile              # Container definition
├── .env.example            # Esempio variabili d'ambiente
└── .dockerignore           # File esclusi da Docker build
```

## 1. Configuration (`app/config.py`)

### Scopo
Centralizza tutta la configurazione dell'applicazione usando Pydantic Settings.

### Codice Chiave

```python
class Settings(BaseSettings):
    # AWS Configuration
    aws_region: str = "eu-west-1"
    dynamodb_table_name: str = "fastapi-tutorial-items"
    secret_name: str = "fastapi-tutorial-secrets"
    
    # Application Configuration
    app_name: str = "FastAPI AWS Tutorial"
    debug: bool = False
    
    # Secret values (caricati a runtime)
    api_key: Optional[str] = None
    
    class Config:
        env_file = ".env"
        case_sensitive = False
```

### Come Funziona

1. **Pydantic Settings**: Carica automaticamente da environment variables
2. **Type Safety**: Validazione automatica dei tipi
3. **Defaults**: Valori di default per sviluppo locale
4. **Env File**: Supporto per file `.env` in sviluppo

### Metodo `safe_dict()`

```python
def safe_dict(self) -> dict:
    """Nasconde valori sensibili per logging sicuro"""
    config = {
        "aws_region": self.aws_region,
        "api_key": "***" if self.api_key else None,  # Mascherato!
    }
    return config
```

**Perché è importante**: Previene leak di secrets nei log.

### Uso nel Codice

```python
from app.config import settings

# Accesso diretto
print(settings.aws_region)  # "eu-west-1"

# Logging sicuro
logger.info("Config loaded", extra=settings.safe_dict())
```

## 2. Secrets Manager Client (`app/secrets.py`)

### Scopo
Gestisce il recupero sicuro di secrets da AWS Secrets Manager.

### Codice Chiave

```python
class SecretsClient:
    def __init__(self, region: str):
        self.client = boto3.client('secretsmanager', region_name=region)
        self._cache: Dict[str, dict] = {}  # Cache in-memory
    
    def get_secret(self, secret_name: str, use_cache: bool = True) -> dict:
        # Controlla cache
        if use_cache and secret_name in self._cache:
            return self._cache[secret_name]
        
        # Recupera da AWS
        response = self.client.get_secret_value(SecretId=secret_name)
        secret_data = json.loads(response['SecretString'])
        
        # Salva in cache
        self._cache[secret_name] = secret_data
        return secret_data
```

### Pattern Implementati

1. **Caching**: Riduce chiamate API e latenza
2. **Error Handling**: Gestisce secrets non trovati, access denied, etc.
3. **JSON Parsing**: Converte automaticamente secrets JSON in dict

### Gestione Errori

```python
except ClientError as e:
    error_code = e.response['Error']['Code']
    
    if error_code == 'ResourceNotFoundException':
        logger.error(f"Secret '{secret_name}' non trovato")
    elif error_code == 'AccessDeniedException':
        logger.error(f"Accesso negato. Verifica IAM permissions")
```

**Perché è importante**: Fornisce messaggi di errore chiari per debugging.

### Uso nel Codice

```python
secrets_client = SecretsClient(region="eu-west-1")

# Recupera tutto il secret
secret_data = secrets_client.get_secret("my-secret")
api_key = secret_data['api_key']

# Oppure recupera un valore specifico
api_key = secrets_client.get_secret_value("my-secret", "api_key")
```

## 3. DynamoDB Client (`app/database.py`)

### Scopo
Astrae tutte le operazioni CRUD su DynamoDB.

### Inizializzazione

```python
class DynamoDBClient:
    def __init__(self, table_name: str, region: str):
        dynamodb = boto3.resource('dynamodb', region_name=region)
        self.table = dynamodb.Table(table_name)
```

**Nota**: Usa `resource` invece di `client` per API più semplice.

### Create Item

```python
def create_item(self, item_data: dict) -> str:
    item_id = str(uuid4())  # Genera UUID
    timestamp = datetime.utcnow().isoformat()
    
    item = {
        'item_id': item_id,
        'name': item_data['name'],
        'description': item_data.get('description'),
        'tags': item_data.get('tags', []),
        'created_at': timestamp,
        'updated_at': timestamp
    }
    
    self.table.put_item(Item=item)
    return item_id
```

**Pattern**: 
- UUID per IDs univoci
- Timestamp automatici
- Gestione campi opzionali con `.get()`

### Get Item

```python
def get_item(self, item_id: str) -> Optional[Dict]:
    response = self.table.get_item(Key={'item_id': item_id})
    
    if 'Item' not in response:
        raise ItemNotFoundException(f"Item '{item_id}' non trovato")
    
    return response['Item']
```

**Pattern**: Eccezione custom per item non trovato (diventa HTTP 404).

### List Items

```python
def list_items(self, limit: int = 100) -> List[Dict]:
    response = self.table.scan(Limit=limit)
    return response.get('Items', [])
```

**Nota**: `scan` è costoso su tabelle grandi. Per produzione, considera query con indici.

### Health Check

```python
def health_check(self) -> bool:
    response = self.table.meta.client.describe_table(
        TableName=self.table_name
    )
    return response['Table']['TableStatus'] == 'ACTIVE'
```

**Uso**: Verifica connessione per endpoint `/health`.

## 4. Data Models (`app/models.py`)

### Scopo
Definisce i contratti API con validazione automatica.

### Input Model

```python
class ItemCreate(BaseModel):
    name: str = Field(
        ...,  # Required
        description="Nome dell'item",
        min_length=1,
        max_length=100,
        examples=["Laptop Dell XPS"]
    )
    description: Optional[str] = Field(None, max_length=500)
    tags: List[str] = Field(default_factory=list)
```

**Features**:
- Validazione automatica (min/max length)
- Documentazione OpenAPI
- Type hints per IDE
- Valori di default

### Output Model

```python
class ItemResponse(BaseModel):
    item_id: str
    name: str
    description: Optional[str]
    tags: List[str]
    created_at: str
    updated_at: str
```

**Uso**: FastAPI serializza automaticamente da dict a JSON.

### Esempio di Validazione

```python
# Input valido
item = ItemCreate(name="Laptop", tags=["tech"])  # OK

# Input non valido
item = ItemCreate(name="")  # ValidationError: min_length=1
item = ItemCreate(name="x" * 101)  # ValidationError: max_length=100
```

## 5. FastAPI Application (`app/main.py`)

### Lifecycle Management

```python
@asynccontextmanager
async def lifespan(app: FastAPI):
    """Inizializzazione all'avvio"""
    global db_client, secrets_client
    
    # Startup
    secrets_client = SecretsClient(region=settings.aws_region)
    secret_data = secrets_client.get_secret(settings.secret_name)
    settings.api_key = secret_data.get('api_key')
    
    db_client = DynamoDBClient(
        table_name=settings.dynamodb_table_name,
        region=settings.aws_region
    )
    
    yield  # Applicazione running
    
    # Shutdown (cleanup se necessario)
```

**Pattern**: Lifespan events per inizializzazione una tantum.

### Endpoint Example: Create Item

```python
@app.post(
    "/items",
    response_model=ItemResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Crea nuovo item",
    description="Crea un nuovo item nel database DynamoDB"
)
async def create_item(item: ItemCreate):
    try:
        # Crea item
        item_id = db_client.create_item(item.model_dump())
        
        # Recupera item creato
        created_item = db_client.get_item(item_id)
        
        # Ritorna come ItemResponse
        return ItemResponse(**created_item)
        
    except ClientError as e:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Errore nella comunicazione con il database"
        )
```

**Flow**:
1. FastAPI valida input con `ItemCreate`
2. Converte a dict con `model_dump()`
3. Crea item in DynamoDB
4. Recupera item completo
5. Converte a `ItemResponse`
6. FastAPI serializza a JSON

### Exception Handlers

```python
@app.exception_handler(ItemNotFoundException)
async def item_not_found_handler(request, exc):
    return JSONResponse(
        status_code=status.HTTP_404_NOT_FOUND,
        content={
            "error": "ItemNotFound",
            "message": str(exc)
        }
    )
```

**Beneficio**: Errori consistenti in tutta l'API.

## 6. Logging (`app/logging_config.py`)

### JSON Formatter

```python
class CustomJsonFormatter(jsonlogger.JsonFormatter):
    def add_fields(self, log_record, record, message_dict):
        super().add_fields(log_record, record, message_dict)
        
        log_record['level'] = record.levelname
        log_record['logger'] = record.name
        
        # Redact sensitive data
        sensitive_keys = ['password', 'token', 'api_key']
        for key in sensitive_keys:
            if key in log_record:
                log_record[key] = '***REDACTED***'
```

**Output Example**:
```json
{
  "timestamp": "2025-02-12T10:30:00.123Z",
  "level": "INFO",
  "logger": "app.database",
  "message": "Item creato",
  "item_id": "123...",
  "api_key": "***REDACTED***"
}
```

### Setup

```python
def setup_logging(debug: bool = False):
    handler = logging.StreamHandler(sys.stdout)
    formatter = CustomJsonFormatter('%(timestamp)s %(level)s %(message)s')
    handler.setFormatter(formatter)
    
    root_logger = logging.getLogger()
    root_logger.addHandler(handler)
```

## 7. Middleware (`app/middleware.py`)

### Request Logging

```python
class RequestLoggingMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        start_time = time.time()
        
        # Log richiesta
        logger.info("Richiesta ricevuta", extra={
            "method": request.method,
            "path": request.url.path
        })
        
        # Processa richiesta
        response = await call_next(request)
        
        # Log risposta
        duration = time.time() - start_time
        logger.info("Richiesta completata", extra={
            "status_code": response.status_code,
            "duration_ms": round(duration * 1000, 2)
        })
        
        return response
```

**Beneficio**: Logging automatico di tutte le richieste.

## Pattern e Best Practices

### 1. Dependency Injection

FastAPI usa DI implicita:

```python
# Invece di passare db_client manualmente
@app.get("/items")
async def list_items():
    items = db_client.list_items()  # Usa global client
    return items
```

### 2. Error Handling Layers

```
1. Try/Except in client methods (database.py, secrets.py)
2. Try/Except in endpoints (main.py)
3. Exception handlers globali (main.py)
```

### 3. Type Safety

```python
# Type hints ovunque
def create_item(self, item_data: dict) -> str:
    ...

# Pydantic per validazione runtime
class ItemCreate(BaseModel):
    name: str
```

### 4. Separation of Concerns

- `config.py`: Solo configurazione
- `database.py`: Solo operazioni DB
- `secrets.py`: Solo gestione secrets
- `main.py`: Solo routing e orchestrazione

## Testing Locale

### Setup Ambiente

```bash
# Crea .env file
cp .env.example .env

# Modifica .env con valori locali
AWS_REGION=eu-west-1
DYNAMODB_TABLE_NAME=fastapi-tutorial-items
SECRET_NAME=fastapi-tutorial-secrets
DEBUG=true
```

### Run Locale

```bash
# Installa dipendenze
pip install -r requirements.txt

# Run con uvicorn
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### Test con curl

```bash
# Health check
curl http://localhost:8000/health

# Crea item
curl -X POST http://localhost:8000/items \
  -H "Content-Type: application/json" \
  -d '{"name":"Test","description":"Item di test","tags":["test"]}'

# Lista items
curl http://localhost:8000/items
```

### Documentazione Interattiva

Apri browser: `http://localhost:8000/docs`

FastAPI genera automaticamente:
- Swagger UI interattivo
- Documentazione di tutti gli endpoints
- Try-it-out per testare API

## Estendere l'Applicazione

### Aggiungere un Nuovo Endpoint

1. **Definisci modelli** in `models.py`:
```python
class ItemUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
```

2. **Aggiungi metodo** in `database.py`:
```python
def update_item(self, item_id: str, updates: dict) -> bool:
    self.table.update_item(
        Key={'item_id': item_id},
        UpdateExpression="SET #n = :name",
        ExpressionAttributeNames={'#n': 'name'},
        ExpressionAttributeValues={':name': updates['name']}
    )
    return True
```

3. **Crea endpoint** in `main.py`:
```python
@app.patch("/items/{item_id}", response_model=ItemResponse)
async def update_item(item_id: str, updates: ItemUpdate):
    db_client.update_item(item_id, updates.model_dump(exclude_unset=True))
    updated_item = db_client.get_item(item_id)
    return ItemResponse(**updated_item)
```

### Aggiungere Autenticazione

```python
from fastapi.security import HTTPBearer

security = HTTPBearer()

@app.get("/protected")
async def protected_route(credentials: HTTPAuthorizationCredentials = Depends(security)):
    # Verifica token
    if credentials.credentials != settings.api_key:
        raise HTTPException(status_code=401)
    return {"message": "Accesso autorizzato"}
```

## Debugging

### Log Levels

```python
# In .env
DEBUG=true  # Abilita logging DEBUG

# Nel codice
logger.debug("Dettagli per debugging")
logger.info("Informazioni generali")
logger.warning("Attenzione")
logger.error("Errore")
```

### CloudWatch Logs

```bash
# Visualizza log su AWS
aws logs tail /aws/apprunner/<service-name> --follow
```

### Common Issues

1. **Import Error**: Verifica che `app/` sia un package (ha `__init__.py`)
2. **Connection Error**: Verifica IAM permissions e region
3. **Validation Error**: Controlla i modelli Pydantic

## Prossimi Passi

- Leggi [ARCHITECTURE.md](./ARCHITECTURE.md) per capire il big picture
- Consulta [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) per problemi comuni
- Sperimenta aggiungendo nuovi endpoint
- Prova a implementare autenticazione JWT
