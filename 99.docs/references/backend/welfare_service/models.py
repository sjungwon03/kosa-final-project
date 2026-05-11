from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Numeric, Text
from datetime import datetime

from shared.database import Base


class Product(Base):
    __tablename__ = "products"
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(200))
    description = Column(Text)
    price = Column(Numeric(10, 2))
    stock = Column(Integer, default=0)
    category = Column(String(50))
    image_url = Column(String(500))
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class Order(Base):
    __tablename__ = "orders"
    
    id = Column(Integer, primary_key=True, index=True)
    employee_id = Column(Integer, ForeignKey("employees.id"))
    order_number = Column(String(50), unique=True, index=True)
    total_amount = Column(Numeric(10, 2))
    status = Column(String(20), default="pending")
    shipping_address = Column(String(500))
    phone = Column(String(20))
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class OrderItem(Base):
    __tablename__ = "order_items"
    
    id = Column(Integer, primary_key=True, index=True)
    order_id = Column(Integer, ForeignKey("orders.id"))
    product_id = Column(Integer, ForeignKey("products.id"))
    quantity = Column(Integer)
    price = Column(Numeric(10, 2))


class Point(Base):
    __tablename__ = "points"
    
    id = Column(Integer, primary_key=True, index=True)
    employee_id = Column(Integer, ForeignKey("employees.id"))
    amount = Column(Numeric(10, 2))
    type = Column(String(20))
    description = Column(Text)
    created_at = Column(DateTime, default=datetime.utcnow)