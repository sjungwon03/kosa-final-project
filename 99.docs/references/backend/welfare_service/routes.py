from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from welfare_service.models import Product, Order
from welfare_service.schemas import ProductCreate, ProductUpdate, ProductResponse, OrderCreate, OrderResponse, PointCreate, PointResponse
from welfare_service.service import ProductService, OrderService, PointService
from shared.database import get_db
from decimal import Decimal

router = APIRouter()


@router.post("/products", response_model=ProductResponse)
async def create_product(
    product_data: ProductCreate,
    db: AsyncSession = Depends(get_db)
):
    service = ProductService(db)
    product = await service.create_product(product_data)
    return product


@router.get("/products", response_model=List[ProductResponse])
async def get_products(
    skip: int = 0,
    limit: int = 100,
    category: Optional[str] = None,
    db: AsyncSession = Depends(get_db)
):
    service = ProductService(db)
    products = await service.get_products(skip, limit, category)
    return products


@router.get("/products/{product_id}", response_model=ProductResponse)
async def get_product(
    product_id: int,
    db: AsyncSession = Depends(get_db)
):
    service = ProductService(db)
    product = await service.get_product(product_id)
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    return product


@router.put("/products/{product_id}", response_model=ProductResponse)
async def update_product(
    product_id: int,
    product_data: ProductUpdate,
    db: AsyncSession = Depends(get_db)
):
    service = ProductService(db)
    product = await service.update_product(product_id, product_data)
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    return product


@router.delete("/products/{product_id}")
async def delete_product(
    product_id: int,
    db: AsyncSession = Depends(get_db)
):
    service = ProductService(db)
    success = await service.delete_product(product_id)
    if not success:
        raise HTTPException(status_code=404, detail="Product not found")
    return {"message": "Product deleted successfully"}


@router.post("/orders", response_model=OrderResponse)
async def create_order(
    order_data: OrderCreate,
    db: AsyncSession = Depends(get_db)
):
    service = OrderService(db)
    try:
        order = await service.create_order(order_data)
        return order
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/orders", response_model=List[OrderResponse])
async def get_orders(
    skip: int = 0,
    limit: int = 100,
    employee_id: Optional[int] = None,
    db: AsyncSession = Depends(get_db)
):
    service = OrderService(db)
    orders = await service.get_orders(skip, limit, employee_id)
    return orders


@router.get("/orders/{order_id}", response_model=OrderResponse)
async def get_order(
    order_id: int,
    db: AsyncSession = Depends(get_db)
):
    service = OrderService(db)
    order = await service.get_order(order_id)
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    return order


@router.put("/orders/{order_id}/status")
async def update_order_status(
    order_id: int,
    status: str,
    db: AsyncSession = Depends(get_db)
):
    service = OrderService(db)
    order = await service.update_order_status(order_id, status)
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    return order


@router.post("/points/earn")
async def earn_points(
    point_data: PointCreate,
    db: AsyncSession = Depends(get_db)
):
    service = PointService(db)
    point = await service.add_point(point_data.employee_id, point_data.amount, point_data.description)
    return {"message": "Points earned successfully", "point": point}


@router.post("/points/use")
async def use_points(
    point_data: PointCreate,
    db: AsyncSession = Depends(get_db)
):
    service = PointService(db)
    try:
        point = await service.use_point(point_data.employee_id, point_data.amount, point_data.description)
        return {"message": "Points used successfully", "point": point}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/points/{employee_id}", response_model=List[PointResponse])
async def get_points(
    employee_id: int,
    skip: int = 0,
    limit: int = 100,
    db: AsyncSession = Depends(get_db)
):
    service = PointService(db)
    points = await service.get_points(employee_id, skip, limit)
    return points


@router.get("/points/{employee_id}/total")
async def get_total_points(
    employee_id: int,
    db: AsyncSession = Depends(get_db)
):
    service = PointService(db)
    total = await service.get_total_points(employee_id)
    return {"employee_id": employee_id, "total": float(total)}