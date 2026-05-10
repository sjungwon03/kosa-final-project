from typing import List, Optional
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from datetime import datetime

from welfare_service.models import Product, Order, OrderItem, Point
from welfare_service.schemas import ProductCreate, ProductUpdate, OrderCreate
from decimal import Decimal


class ProductService:
    def __init__(self, db: AsyncSession):
        self.db = db
    
    async def create_product(self, product_data: ProductCreate) -> Product:
        db_product = Product(**product_data.model_dump())
        self.db.add(db_product)
        await self.db.commit()
        await self.db.refresh(db_product)
        return db_product
    
    async def get_product(self, product_id: int) -> Optional[Product]:
        result = await self.db.execute(select(Product).filter(Product.id == product_id))
        return result.scalar_one_or_none()
    
    async def get_products(self, skip: int = 0, limit: int = 100, category: Optional[str] = None) -> List[Product]:
        query = select(Product)
        if category:
            query = query.filter(Product.category == category)
        query = query.offset(skip).limit(limit)
        result = await self.db.execute(query)
        return result.scalars().all()
    
    async def update_product(self, product_id: int, product_data: ProductUpdate) -> Optional[Product]:
        db_product = await self.get_product(product_id)
        if not db_product:
            return None
        
        update_data = product_data.model_dump(exclude_unset=True)
        for field, value in update_data.items():
            setattr(db_product, field, value)
        
        await self.db.commit()
        await self.db.refresh(db_product)
        return db_product
    
    async def delete_product(self, product_id: int) -> bool:
        db_product = await self.get_product(product_id)
        if not db_product:
            return False
        
        await self.db.delete(db_product)
        await self.db.commit()
        return True


class OrderService:
    def __init__(self, db: AsyncSession):
        self.db = db
    
    async def create_order(self, order_data: OrderCreate) -> Order:
        order_number = f"ORD-{datetime.utcnow().strftime('%Y%m%d%H%M%S')}-{order_data.employee_id}"
        
        total_amount = Decimal(0)
        order_items = []
        
        for item_data in order_data.items:
            product_result = await self.db.execute(select(Product).filter(Product.id == item_data.product_id))
            product = product_result.scalar_one_or_none()
            
            if not product:
                raise ValueError(f"Product {item_data.product_id} not found")
            
            if product.stock < item_data.quantity:
                raise ValueError(f"Insufficient stock for product {product.name}")
            
            item_total = product.price * item_data.quantity
            total_amount += item_total
            
            order_item = OrderItem(
                product_id=item_data.product_id,
                quantity=item_data.quantity,
                price=product.price
            )
            order_items.append(order_item)
            
            product.stock -= item_data.quantity
        
        db_order = Order(
            employee_id=order_data.employee_id,
            order_number=order_number,
            total_amount=total_amount,
            shipping_address=order_data.shipping_address,
            phone=order_data.phone
        )
        
        self.db.add(db_order)
        await self.db.flush()
        
        for order_item in order_items:
            order_item.order_id = db_order.id
            self.db.add(order_item)
        
        await self.db.commit()
        await self.db.refresh(db_order)
        return db_order
    
    async def get_order(self, order_id: int) -> Optional[Order]:
        result = await self.db.execute(select(Order).filter(Order.id == order_id))
        return result.scalar_one_or_none()
    
    async def get_orders(self, skip: int = 0, limit: int = 100, employee_id: Optional[int] = None) -> List[Order]:
        query = select(Order)
        if employee_id:
            query = query.filter(Order.employee_id == employee_id)
        query = query.offset(skip).limit(limit)
        result = await self.db.execute(query)
        return result.scalars().all()
    
    async def update_order_status(self, order_id: int, status: str) -> Optional[Order]:
        db_order = await self.get_order(order_id)
        if not db_order:
            return None
        
        db_order.status = status
        await self.db.commit()
        await self.db.refresh(db_order)
        return db_order


class PointService:
    def __init__(self, db: AsyncSession):
        self.db = db
    
    async def add_point(self, employee_id: int, amount: Decimal, description: str) -> Point:
        db_point = Point(
            employee_id=employee_id,
            amount=amount,
            type="earn",
            description=description
        )
        self.db.add(db_point)
        await self.db.commit()
        await self.db.refresh(db_point)
        return db_point
    
    async def use_point(self, employee_id: int, amount: Decimal, description: str) -> Point:
        result = await self.db.execute(
            select(func.sum(Point.amount)).filter(Point.employee_id == employee_id)
        )
        total_points = result.scalar() or Decimal(0)
        
        if total_points < amount:
            raise ValueError("Insufficient points")
        
        db_point = Point(
            employee_id=employee_id,
            amount=-amount,
            type="spend",
            description=description
        )
        self.db.add(db_point)
        await self.db.commit()
        await self.db.refresh(db_point)
        return db_point
    
    async def get_points(self, employee_id: int, skip: int = 0, limit: int = 100) -> List[Point]:
        result = await self.db.execute(
            select(Point)
            .filter(Point.employee_id == employee_id)
            .order_by(Point.created_at.desc())
            .offset(skip)
            .limit(limit)
        )
        return result.scalars().all()
    
    async def get_total_points(self, employee_id: int) -> Decimal:
        result = await self.db.execute(
            select(func.sum(Point.amount)).filter(Point.employee_id == employee_id)
        )
        return result.scalar() or Decimal(0)