import os
from typing import Optional

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    env: str = "development"
    
    api_gateway_host: str = "0.0.0.0"
    api_gateway_port: int = 8000
    
    employee_service_url: str = "http://employee-service:8001"
    welfare_service_url: str = "http://welfare-service:8002"
    
    mysql_host: str = "localhost"
    mysql_port: int = 3306
    mysql_user: str = "root"
    mysql_password: str = "password"
    mysql_database: str = "kosa"
    
    redis_host: str = "localhost"
    redis_port: int = 6379
    redis_password: Optional[str] = None
    
    secret_key: str = "your-secret-key-here"
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 30
    
    class Config:
        env_file = ".env"


settings = Settings()