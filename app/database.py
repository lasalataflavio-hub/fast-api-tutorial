"""
Client per AWS DynamoDB.
Gestisce operazioni CRUD sulla tabella items.
"""
import logging
from datetime import datetime
from typing import Optional, List, Dict
from uuid import uuid4
import boto3
from botocore.exceptions import ClientError


logger = logging.getLogger(__name__)


class ItemNotFoundException(Exception):
    """Eccezione sollevata quando un item non viene trovato."""
    pass


class DynamoDBClient:
    """
    Client per operazioni CRUD su DynamoDB.
    Gestisce la tabella degli items con retry logic e error handling.
    """
    
    def __init__(self, table_name: str, region: str):
        """
        Inizializza il client DynamoDB.
        
        Args:
            table_name: Nome della tabella DynamoDB
            region: AWS region (es. 'eu-west-1')
        """
        self.table_name = table_name
        self.region = region
        
        # Usa boto3 resource per operazioni semplificate
        dynamodb = boto3.resource('dynamodb', region_name=region)
        self.table = dynamodb.Table(table_name)
        
        logger.info(f"DynamoDBClient inizializzato per tabella: {table_name} in region: {region}")
    
    def create_item(self, item_data: dict) -> str:
        """
        Crea un nuovo item nella tabella DynamoDB.
        
        Args:
            item_data: Dizionario con i dati dell'item (name, description, tags)
        
        Returns:
            ID univoco dell'item creato
        
        Raises:
            ClientError: Se si verifica un errore durante la scrittura
        """
        item_id = str(uuid4())
        timestamp = datetime.utcnow().isoformat()
        
        item = {
            'item_id': item_id,
            'name': item_data['name'],
            'description': item_data.get('description'),
            'tags': item_data.get('tags', []),
            'created_at': timestamp,
            'updated_at': timestamp
        }
        
        try:
            self.table.put_item(Item=item)
            logger.info(f"Item creato con successo: {item_id}")
            return item_id
            
        except ClientError as e:
            error_code = e.response['Error']['Code']
            logger.error(f"Errore nella creazione dell'item: {error_code} - {e}")
            raise
    
    def get_item(self, item_id: str) -> Optional[Dict]:
        """
        Recupera un item dalla tabella per ID.
        
        Args:
            item_id: ID dell'item da recuperare
        
        Returns:
            Dizionario con i dati dell'item, o None se non trovato
        
        Raises:
            ItemNotFoundException: Se l'item non esiste
            ClientError: Se si verifica un errore durante la lettura
        """
        try:
            response = self.table.get_item(Key={'item_id': item_id})
            
            if 'Item' not in response:
                logger.warning(f"Item non trovato: {item_id}")
                raise ItemNotFoundException(f"Item con ID '{item_id}' non trovato")
            
            logger.info(f"Item recuperato con successo: {item_id}")
            return response['Item']
            
        except ClientError as e:
            error_code = e.response['Error']['Code']
            
            if error_code == 'ResourceNotFoundException':
                logger.error(f"Tabella '{self.table_name}' non trovata")
                raise
            else:
                logger.error(f"Errore nel recupero dell'item {item_id}: {error_code} - {e}")
                raise
    
    def list_items(self, limit: int = 100) -> List[Dict]:
        """
        Lista tutti gli items nella tabella.
        
        Args:
            limit: Numero massimo di items da restituire
        
        Returns:
            Lista di dizionari con i dati degli items
        
        Raises:
            ClientError: Se si verifica un errore durante la scansione
        """
        try:
            response = self.table.scan(Limit=limit)
            items = response.get('Items', [])
            
            logger.info(f"Recuperati {len(items)} items dalla tabella")
            return items
            
        except ClientError as e:
            error_code = e.response['Error']['Code']
            
            if error_code == 'ResourceNotFoundException':
                logger.error(f"Tabella '{self.table_name}' non trovata")
                raise
            else:
                logger.error(f"Errore nella scansione della tabella: {error_code} - {e}")
                raise
    
    def delete_item(self, item_id: str) -> bool:
        """
        Elimina un item dalla tabella.
        
        Args:
            item_id: ID dell'item da eliminare
        
        Returns:
            True se l'eliminazione ha successo
        
        Raises:
            ItemNotFoundException: Se l'item non esiste
            ClientError: Se si verifica un errore durante l'eliminazione
        """
        try:
            # Verifica che l'item esista prima di eliminarlo
            self.get_item(item_id)
            
            self.table.delete_item(Key={'item_id': item_id})
            logger.info(f"Item eliminato con successo: {item_id}")
            return True
            
        except ItemNotFoundException:
            raise
        except ClientError as e:
            error_code = e.response['Error']['Code']
            logger.error(f"Errore nell'eliminazione dell'item {item_id}: {error_code} - {e}")
            raise
    
    def health_check(self) -> bool:
        """
        Verifica la connessione a DynamoDB.
        
        Returns:
            True se la connessione è attiva e la tabella esiste
        
        Raises:
            ClientError: Se si verifica un errore nella connessione
        """
        try:
            # Tenta di descrivere la tabella per verificare la connessione
            response = self.table.meta.client.describe_table(TableName=self.table_name)
            table_status = response['Table']['TableStatus']
            
            if table_status == 'ACTIVE':
                logger.info(f"Health check OK: tabella '{self.table_name}' è ACTIVE")
                return True
            else:
                logger.warning(f"Health check: tabella '{self.table_name}' in stato {table_status}")
                return False
                
        except ClientError as e:
            error_code = e.response['Error']['Code']
            
            if error_code == 'ResourceNotFoundException':
                logger.error(f"Health check FAILED: tabella '{self.table_name}' non trovata")
                raise
            else:
                logger.error(f"Health check FAILED: {error_code} - {e}")
                raise
