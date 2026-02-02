"""
Configurazione centralizzata dell'applicazione.
Gestisce variabili d'ambiente e secrets AWS.
"""
from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    """
    Configurazione applicazione usando Pydantic Settings.
    Le variabili vengono caricate da environment variables.
    """
    
    # AWS Configuration
    aws_region: str = "eu-west-1"
    dynamodb_table_name: str = "fastapi-tutorial-items"
    secret_name: str = "fastapi-tutorial-secrets"
    
    # Application Configuration
    app_name: str = "FastAPI AWS Tutorial"
    debug: bool = False
    
    # Secret values (caricati a runtime da Secrets Manager)
    api_key: Optional[str] = None
    database_encryption_key: Optional[str] = None
    
    class Config:
        env_file = ".env"
        case_sensitive = False
    
    def safe_dict(self) -> dict:
        """
        Restituisce un dizionario con la configurazione,
        nascondendo i valori sensibili per logging sicuro.
        """
        config = {
            "aws_region": self.aws_region,
            "dynamodb_table_name": self.dynamodb_table_name,
            "secret_name": self.secret_name,
            "app_name": self.app_name,
            "debug": self.debug,
            "api_key": "***" if self.api_key else None,
            "database_encryption_key": "***" if self.database_encryption_key else None,
        }
        return config


# Istanza globale delle settings
settings = Settings()
