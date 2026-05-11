from typing import List
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from employee_service.models import Employee
from employee_service.schemas import EmployeeCreate, EmployeeUpdate, EmployeeResponse, LoginRequest, TokenResponse
from employee_service.service import EmployeeService
from shared.database import get_db
from shared.auth import create_access_token, get_current_user

router = APIRouter()


@router.post("/login", response_model=TokenResponse)
async def login(
    login_data: LoginRequest,
    db: AsyncSession = Depends(get_db)
):
    service = EmployeeService(db)
    employee = await service.authenticate(login_data.email, login_data.password)
    
    if not employee:
        raise HTTPException(status_code=401, detail="Invalid credentials")
    
    access_token = create_access_token(data={"sub": employee.email, "employee_id": employee.id})
    return {"access_token": access_token}


@router.get("/me", response_model=EmployeeResponse)
async def get_current_employee(
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    service = EmployeeService(db)
    email = current_user.get("sub")
    if not email:
        raise HTTPException(status_code=401, detail="Invalid token")
    employee = await service.get_employee_by_email(email)
    if not employee:
        raise HTTPException(status_code=404, detail="Employee not found")
    return employee


@router.post("/", response_model=EmployeeResponse)
async def create_employee(
    employee_data: EmployeeCreate,
    db: AsyncSession = Depends(get_db)
):
    service = EmployeeService(db)
    employee = await service.create_employee(employee_data)
    return employee


@router.get("/", response_model=List[EmployeeResponse])
async def get_employees(
    skip: int = 0,
    limit: int = 100,
    db: AsyncSession = Depends(get_db)
):
    service = EmployeeService(db)
    employees = await service.get_employees(skip, limit)
    return employees


@router.get("/by-id/{employee_id}", response_model=EmployeeResponse)
async def get_employee_by_string_id(
    employee_id: str,
    db: AsyncSession = Depends(get_db)
):
    service = EmployeeService(db)
    employee = await service.get_employee_by_employee_id(employee_id)
    if not employee:
        raise HTTPException(status_code=404, detail="Employee not found")
    return employee


@router.get("/{employee_id}", response_model=EmployeeResponse)
async def get_employee(
    employee_id: int,
    db: AsyncSession = Depends(get_db)
):
    service = EmployeeService(db)
    employee = await service.get_employee(employee_id)
    if not employee:
        raise HTTPException(status_code=404, detail="Employee not found")
    return employee


@router.put("/by-id/{employee_id}", response_model=EmployeeResponse)
async def update_employee_by_string_id(
    employee_id: str,
    employee_data: EmployeeUpdate,
    db: AsyncSession = Depends(get_db)
):
    service = EmployeeService(db)
    employee = await service.update_employee_by_employee_id(employee_id, employee_data)
    if not employee:
        raise HTTPException(status_code=404, detail="Employee not found")
    return employee


@router.put("/{employee_id}", response_model=EmployeeResponse)
async def update_employee(
    employee_id: int,
    employee_data: EmployeeUpdate,
    db: AsyncSession = Depends(get_db)
):
    service = EmployeeService(db)
    employee = await service.update_employee(employee_id, employee_data)
    if not employee:
        raise HTTPException(status_code=404, detail="Employee not found")
    return employee


@router.delete("/by-id/{employee_id}")
async def delete_employee_by_string_id(
    employee_id: str,
    db: AsyncSession = Depends(get_db)
):
    service = EmployeeService(db)
    success = await service.delete_employee_by_employee_id(employee_id)
    if not success:
        raise HTTPException(status_code=404, detail="Employee not found")
    return {"message": "Employee deleted successfully"}


@router.delete("/{employee_id}")
async def delete_employee(
    employee_id: int,
    db: AsyncSession = Depends(get_db)
):
    service = EmployeeService(db)
    success = await service.delete_employee(employee_id)
    if not success:
        raise HTTPException(status_code=404, detail="Employee not found")
    return {"message": "Employee deleted successfully"}