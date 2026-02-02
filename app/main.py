# app/main.py
"""
FastAPI application con integrazione AWS DynamoDB e Secrets Manager.
Progetto didattico per insegnare best practices AWS.
"""
import logging
from datetime import datetime
from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException, status
from fastapi.responses import JSONResponse
from botocore.exceptions import ClientError, NoCredentialsError

from app.config import settings
from app.database import DynamoDBClient, ItemNotFoundException
from app.aws_secrets import SecretsClient
from app.models import (
    ItemCreate,
    ItemResponse,
    ItemsListResponse,
    HealthResponse,
    ConfigResponse,
    ErrorResponse,
)
from app.logging_config import setup_logging, get_logger
from app.middleware import RequestLoggingMiddleware

# Configurazione logging strutturato
setup_logging(debug=settings.debug)
logger = get_logger(__name__)

# Client globali (inizializzati al startup)
db_client: DynamoDBClient = None
secrets_client: SecretsClient = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Gestisce il ciclo di vita dell'applicazione.
    Inizializza i client AWS all'avvio.
    """
    global db_client, secrets_client

    logger.info("=== Avvio applicazione FastAPI AWS Tutorial ===")

    try:
        # Inizializza Secrets Manager client
        logger.info("Inizializzazione SecretsClient...")
        secrets_client = SecretsClient(region=settings.aws_region)

        # Carica secrets (opzionale, solo se il secret esiste)
        try:
            secret_data = secrets_client.get_secret(settings.secret_name)
            settings.api_key = secret_data.get("api_key")
            settings.database_encryption_key = secret_data.get(
                "database_encryption_key"
            )
            logger.info("Secrets caricati con successo")
        except (ClientError, NoCredentialsError) as e:
            # In sviluppo locale, le credenziali AWS potrebbero non essere configurate
            logger.warning(
                f"Impossibile caricare secrets: {e}. Continuo senza secrets."
            )

        # Inizializza DynamoDB client
        logger.info("Inizializzazione DynamoDBClient...")
        db_client = DynamoDBClient(
            table_name=settings.dynamodb_table_name, region=settings.aws_region
        )

        # Verifica connessione
        try:
            if db_client.health_check():
                logger.info("Connessione a DynamoDB verificata con successo")
        except (ClientError, NoCredentialsError) as e:
            # In sviluppo locale, potrebbe non esserci connessione a DynamoDB
            logger.warning(
                f"Impossibile verificare connessione DynamoDB: {e}. Continuo comunque."
            )

        logger.info("=== Applicazione avviata con successo ===")

    except Exception as e:
        logger.error(f"Errore durante l'inizializzazione: {e}")
        raise

    yield

    # Cleanup (se necessario)
    logger.info("=== Shutdown applicazione ===")


app = FastAPI(
    title=settings.app_name,
    description="API didattica per imparare l'integrazione AWS con FastAPI",
    version="1.0.0",
    lifespan=lifespan,
)

# Aggiungi middleware per logging
app.add_middleware(RequestLoggingMiddleware)


@app.get(
    "/",
    summary="Welcome endpoint",
    description="Restituisce un messaggio di benvenuto con lo stato della connessione al database",
)
async def read_root():
    """Endpoint di benvenuto con informazioni sullo stato del sistema."""
    db_status = "disconnected"

    if db_client:
        try:
            if db_client.health_check():
                db_status = "connected"
        except Exception:
            db_status = "error"

    return {
        "message": "Benvenuto al FastAPI AWS Tutorial!",
        "description": "API didattica per imparare DynamoDB e Secrets Manager",
        "database_status": db_status,
        "endpoints": {
            "docs": "/docs",
            "health": "/health",
            "config": "/config",
            "items": "/items",
        },
    }


@app.get(
    "/health",
    response_model=HealthResponse,
    summary="Health check",
    description="Verifica lo stato di salute dell'applicazione e della connessione a DynamoDB",
)
async def health_check():
    """Endpoint per health check dell'applicazione."""
    db_status = "disconnected"
    overall_status = "unhealthy"

    try:
        if db_client and db_client.health_check():
            db_status = "connected"
            overall_status = "healthy"
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        db_status = "error"

    return HealthResponse(
        status=overall_status,
        database=db_status,
        timestamp=datetime.utcnow().isoformat(),
    )


@app.get(
    "/config",
    response_model=ConfigResponse,
    summary="Configurazione",
    description="Mostra la configurazione dell'applicazione (senza esporre valori sensibili)",
)
async def get_config():
    """Endpoint per visualizzare la configurazione safe."""
    safe_config = settings.safe_dict()

    return ConfigResponse(
        aws_region=safe_config["aws_region"],
        dynamodb_table_name=safe_config["dynamodb_table_name"],
        secret_name=safe_config["secret_name"],
        app_name=safe_config["app_name"],
        debug=safe_config["debug"],
        api_key_loaded=settings.api_key is not None,
    )


@app.post(
    "/items",
    response_model=ItemResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Crea nuovo item",
    description="Crea un nuovo item nel database DynamoDB",
)
async def create_item(item: ItemCreate):
    """Crea un nuovo item."""
    try:
        item_id = db_client.create_item(item.model_dump())
        created_item = db_client.get_item(item_id)

        return ItemResponse(**created_item)

    except ClientError as e:
        logger.error(f"Errore nella creazione dell'item: {e}")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Errore nella comunicazione con il database",
        )


@app.get(
    "/items",
    response_model=ItemsListResponse,
    summary="Lista items",
    description="Recupera tutti gli items dal database",
)
async def list_items(limit: int = 100):
    """Lista tutti gli items."""
    try:
        items = db_client.list_items(limit=limit)

        return ItemsListResponse(
            items=[ItemResponse(**item) for item in items], count=len(items)
        )

    except ClientError as e:
        logger.error(f"Errore nel recupero degli items: {e}")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Errore nella comunicazione con il database",
        )


@app.get(
    "/items/{item_id}",
    response_model=ItemResponse,
    summary="Recupera item",
    description="Recupera un item specifico per ID",
)
async def get_item(item_id: str):
    """Recupera un item per ID."""
    try:
        item = db_client.get_item(item_id)
        return ItemResponse(**item)

    except ItemNotFoundException:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Item con ID '{item_id}' non trovato",
        )
    except ClientError as e:
        logger.error(f"Errore nel recupero dell'item: {e}")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Errore nella comunicazione con il database",
        )


@app.delete(
    "/items/{item_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Elimina item",
    description="Elimina un item dal database",
)
async def delete_item(item_id: str):
    """Elimina un item."""
    try:
        db_client.delete_item(item_id)
        return None

    except ItemNotFoundException:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Item con ID '{item_id}' non trovato",
        )
    except ClientError as e:
        logger.error(f"Errore nell'eliminazione dell'item: {e}")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Errore nella comunicazione con il database",
        )


# Exception handlers personalizzati
@app.exception_handler(ClientError)
async def aws_client_error_handler(request, exc: ClientError):
    """Gestisce errori generici di AWS SDK."""
    error_code = exc.response["Error"]["Code"]
    logger.error(f"AWS ClientError: {error_code} - {exc}")

    return JSONResponse(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        content={
            "error": "AWSServiceError",
            "message": "Errore nella comunicazione con i servizi AWS",
            "detail": error_code,
        },
    )


@app.exception_handler(ItemNotFoundException)
async def item_not_found_handler(request, exc: ItemNotFoundException):
    """Gestisce errori di item non trovato."""
    return JSONResponse(
        status_code=status.HTTP_404_NOT_FOUND,
        content={"error": "ItemNotFound", "message": str(exc), "detail": None},
    )
