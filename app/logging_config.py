"""
Configurazione logging strutturato per CloudWatch.
Usa JSON formatter per facilitare il parsing dei log.
"""
import logging
import sys
from pythonjsonlogger import jsonlogger


class CustomJsonFormatter(jsonlogger.JsonFormatter):
    """
    Formatter JSON personalizzato che aggiunge campi standard.
    """
    def add_fields(self, log_record, record, message_dict):
        super(CustomJsonFormatter, self).add_fields(log_record, record, message_dict)
        
        # Aggiungi campi standard
        log_record['level'] = record.levelname
        log_record['logger'] = record.name
        log_record['module'] = record.module
        log_record['function'] = record.funcName
        
        # Rimuovi campi sensibili se presenti
        sensitive_keys = ['password', 'token', 'secret', 'api_key', 'authorization']
        for key in sensitive_keys:
            if key in log_record:
                log_record[key] = '***REDACTED***'


def setup_logging(debug: bool = False):
    """
    Configura il logging strutturato per l'applicazione.
    
    Args:
        debug: Se True, imposta il livello a DEBUG
    """
    # Determina il livello di log
    log_level = logging.DEBUG if debug else logging.INFO
    
    # Crea handler per stdout
    handler = logging.StreamHandler(sys.stdout)
    
    # Usa JSON formatter
    formatter = CustomJsonFormatter(
        '%(timestamp)s %(level)s %(name)s %(message)s',
        timestamp=True
    )
    handler.setFormatter(formatter)
    
    # Configura root logger
    root_logger = logging.getLogger()
    root_logger.setLevel(log_level)
    root_logger.addHandler(handler)
    
    # Riduci verbosità di alcuni logger di terze parti
    logging.getLogger('boto3').setLevel(logging.WARNING)
    logging.getLogger('botocore').setLevel(logging.WARNING)
    logging.getLogger('urllib3').setLevel(logging.WARNING)
    
    logging.info("Logging strutturato configurato", extra={
        "log_level": logging.getLevelName(log_level),
        "format": "JSON"
    })


def get_logger(name: str) -> logging.Logger:
    """
    Ottiene un logger configurato.
    
    Args:
        name: Nome del logger (tipicamente __name__)
    
    Returns:
        Logger configurato
    """
    return logging.getLogger(name)
