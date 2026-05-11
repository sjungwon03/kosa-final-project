from pydantic import BaseModel, EmailStr
from datetime import datetime
from typing import Optional, List
from decimal import Decimal


class ProductCreate(BaseModel):
    name: str
    description: str
    price: Decimal
    stock: int
    category: str
    image_url: str


class ProductUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    price: Optional[Decimal] = None
    stock: Optional[int] = None
    category: Optional[str] = None
    image_url: Optional[str] = None


class ProductResponse(BaseModel):
    id: int
    name: str
    description: str
    price: Decimal
    stock: int
    category: str
    image_url: str
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True


class OrderItemCreate(BaseModel):
    product_id: int
    quantity: int


class OrderCreate(BaseModel):
    employee_id: int
    items: List[OrderItemCreate]
    shipping_address: str
    phone: str


class OrderResponse(BaseModel):
    id: int
    employee_id: int
    order_number: str
    total_amount: Decimal
    status: str
    shipping_address: str
    phone: str
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True


class PointCreate(BaseModel):
    employee_id: int
    amount: Decimal
    type: str
    description: str


class PointResponse(BaseModel):
    id: int
    employee_id: int
    amount: Decimal
    type: str
    description: str
    created_at: datetime
    
    class Config:
        from_attributes = True