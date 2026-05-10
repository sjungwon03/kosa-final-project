from sqlalchemy import Column, Integer, String, DateTime
from datetime import datetime

from shared.database import Base


class Employee(Base):
    __tablename__ = "employees"
    
    id = Column(Integer, primary_key=True, index=True)
    employee_id = Column(String(50), unique=True, index=True)
    name = Column(String(100))
    email = Column(String(100), unique=True, index=True)
    department = Column(String(100))
    position = Column(String(100))
    phone = Column(String(20))
    hire_date = Column(DateTime)
    status = Column(String(20), default="active")
    hashed_password = Column(String(255))
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)