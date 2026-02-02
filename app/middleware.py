"""
Middleware per logging delle richieste/risposte.
"""
import time
import logging
from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware


logger = logging.getLogger(__name__)


class RequestLoggingMiddleware(BaseHTTPMiddleware):
    """
    Middleware che logga informazioni su ogni richiesta HTTP.
    """
    
    async def dispatch(self, request: Request, call_next):
        """
        Processa la richiesta e logga informazioni.
        """
        # Timestamp inizio
        start_time = time.time()
        
        # Informazioni richiesta
        request_info = {
            "method": request.method,
            "path": request.url.path,
            "query_params": str(request.query_params),
            "client_host": request.client.host if request.client else None,
        }
        
        logger.info("Richiesta ricevuta", extra=request_info)
        
        # Processa la richiesta
        try:
            response = await call_next(request)
            
            # Calcola durata
            duration = time.time() - start_time
            
            # Log risposta
            response_info = {
                **request_info,
                "status_code": response.status_code,
                "duration_ms": round(duration * 1000, 2)
            }
            
            logger.info("Richiesta completata", extra=response_info)
            
            return response
            
        except Exception as e:
            # Log errore
            duration = time.time() - start_time
            error_info = {
                **request_info,
                "error": str(e),
                "error_type": type(e).__name__,
                "duration_ms": round(duration * 1000, 2)
            }
            
            logger.error("Errore durante la richiesta", extra=error_info)
            raise
