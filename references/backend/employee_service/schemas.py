from pydantic import BaseModel, EmailStr, field_validator
from datetime import datetime
from typing import Optional


class EmployeeCreate(BaseModel):
    employee_id: str
    name: str
    email: EmailStr
    department: str
    position: str
    phone: str
    hire_date: datetime
    password: str
    
    @field_validator('hire_date', mode='before')
    @classmethod
    def parse_hire_date(cls, value):
        if isinstance(value, str):
            try:
                return datetime.fromisoformat(value.replace('Z', '+00:00'))
            except:
                return datetime.strptime(value, '%Y-%m-%d')
        return value


class EmployeeUpdate(BaseModel):
    name: Optional[str] = None
    email: Optional[EmailStr] = None
    department: Optional[str] = None
    position: Optional[str] = None
    phone: Optional[str] = None
    status: Optional[str] = None


class EmployeeResponse(BaseModel):
    id: int
    employee_id: str
    name: str
    email: str
    department: str
    position: str
    phone: str
    hire_date: datetime
    status: str
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True


class LoginRequest(BaseModel):
    email: str
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"