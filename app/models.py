"""
Modelli Pydantic per request/response dell'API.
Forniscono validazione automatica e documentazione OpenAPI.
"""
from pydantic import BaseModel, Field
from typing import Optional, List


class ItemCreate(BaseModel):
    """
    Modello per la creazione di un nuovo item.
    """
    name: str = Field(
        ...,
        description="Nome dell'item",
        min_length=1,
        max_length=100,
        examples=["Laptop Dell XPS"]
    )
    description: Optional[str] = Field(
        None,
        description="Descrizione opzionale dell'item",
        max_length=500,
        examples=["Laptop per sviluppo con 16GB RAM"]
    )
    tags: List[str] = Field(
        default_factory=list,
        description="Lista di tag per categorizzare l'item",
        examples=[["elettronica", "computer", "lavoro"]]
    )
    
    class Config:
        json_schema_extra = {
            "example": {
                "name": "Laptop Dell XPS",
                "description": "Laptop per sviluppo con 16GB RAM",
                "tags": ["elettronica", "computer", "lavoro"]
            }
        }


class ItemResponse(BaseModel):
    """
    Modello per la risposta con i dati di un item.
    """
    item_id: str = Field(
        ...,
        description="ID univoco dell'item (UUID)",
        examples=["123e4567-e89b-12d3-a456-426614174000"]
    )
    name: str = Field(
        ...,
        description="Nome dell'item",
        examples=["Laptop Dell XPS"]
    )
    description: Optional[str] = Field(
        None,
        description="Descrizione dell'item",
        examples=["Laptop per sviluppo con 16GB RAM"]
    )
    tags: List[str] = Field(
        default_factory=list,
        description="Lista di tag",
        examples=[["elettronica", "computer", "lavoro"]]
    )
    created_at: str = Field(
        ...,
        description="Timestamp di creazione (ISO-8601)",
        examples=["2025-02-12T10:30:00.000000"]
    )
    updated_at: str = Field(
        ...,
        description="Timestamp ultimo aggiornamento (ISO-8601)",
        examples=["2025-02-12T10:30:00.000000"]
    )
    
    class Config:
        json_schema_extra = {
            "example": {
                "item_id": "123e4567-e89b-12d3-a456-426614174000",
                "name": "Laptop Dell XPS",
                "description": "Laptop per sviluppo con 16GB RAM",
                "tags": ["elettronica", "computer", "lavoro"],
                "created_at": "2025-02-12T10:30:00.000000",
                "updated_at": "2025-02-12T10:30:00.000000"
            }
        }


class ItemsListResponse(BaseModel):
    """
    Modello per la risposta con lista di items.
    """
    items: List[ItemResponse] = Field(
        ...,
        description="Lista di items"
    )
    count: int = Field(
        ...,
        description="Numero di items restituiti"
    )


class HealthResponse(BaseModel):
    """
    Modello per la risposta dell'health check.
    """
    status: str = Field(
        ...,
        description="Stato generale dell'applicazione",
        examples=["healthy", "unhealthy"]
    )
    database: str = Field(
        ...,
        description="Stato della connessione al database",
        examples=["connected", "disconnected"]
    )
    timestamp: str = Field(
        ...,
        description="Timestamp del check (ISO-8601)",
        examples=["2025-02-12T10:30:00.000000"]
    )
    
    class Config:
        json_schema_extra = {
            "example": {
                "status": "healthy",
                "database": "connected",
                "timestamp": "2025-02-12T10:30:00.000000"
            }
        }


class ConfigResponse(BaseModel):
    """
    Modello per la risposta con la configurazione (valori safe).
    """
    aws_region: str = Field(..., description="AWS Region configurata")
    dynamodb_table_name: str = Field(..., description="Nome tabella DynamoDB")
    secret_name: str = Field(..., description="Nome del secret in Secrets Manager")
    app_name: str = Field(..., description="Nome dell'applicazione")
    debug: bool = Field(..., description="Modalità debug attiva")
    api_key_loaded: bool = Field(..., description="Indica se l'API key è stata caricata")
    
    class Config:
        json_schema_extra = {
            "example": {
                "aws_region": "eu-west-1",
                "dynamodb_table_name": "fastapi-tutorial-items",
                "secret_name": "fastapi-tutorial-secrets",
                "app_name": "FastAPI AWS Tutorial",
                "debug": False,
                "api_key_loaded": True
            }
        }


class ErrorResponse(BaseModel):
    """
    Modello per le risposte di errore.
    """
    error: str = Field(..., description="Tipo di errore")
    message: str = Field(..., description="Messaggio descrittivo dell'errore")
    detail: Optional[str] = Field(None, description="Dettagli aggiuntivi sull'errore")
    
    class Config:
        json_schema_extra = {
            "example": {
                "error": "ItemNotFound",
                "message": "Item con ID '123' non trovato",
                "detail": None
            }
        }
