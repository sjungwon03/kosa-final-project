from typing import List, Optional
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from employee_service.models import Employee
from employee_service.schemas import EmployeeCreate, EmployeeUpdate
from shared.auth import get_password_hash, verify_password


class EmployeeService:
    def __init__(self, db: AsyncSession):
        self.db = db
    
    async def create_employee(self, employee_data: EmployeeCreate) -> Employee:
        hashed_password = get_password_hash(employee_data.password)
        db_employee = Employee(
            employee_id=employee_data.employee_id,
            name=employee_data.name,
            email=employee_data.email,
            department=employee_data.department,
            position=employee_data.position,
            phone=employee_data.phone,
            hire_date=employee_data.hire_date,
            hashed_password=hashed_password
        )
        self.db.add(db_employee)
        await self.db.commit()
        await self.db.refresh(db_employee)
        return db_employee
    
    async def get_employee(self, employee_id: int) -> Optional[Employee]:
        result = await self.db.execute(select(Employee).filter(Employee.id == employee_id))
        return result.scalar_one_or_none()
    
    async def get_employee_by_employee_id(self, employee_id: str) -> Optional[Employee]:
        result = await self.db.execute(select(Employee).filter(Employee.employee_id == employee_id))
        return result.scalar_one_or_none()
    
    async def get_employee_by_email(self, email: str) -> Optional[Employee]:
        result = await self.db.execute(select(Employee).filter(Employee.email == email))
        return result.scalar_one_or_none()
    
    async def get_employees(self, skip: int = 0, limit: int = 100) -> List[Employee]:
        result = await self.db.execute(select(Employee).offset(skip).limit(limit))
        return result.scalars().all()
    
    async def update_employee(self, employee_id: int, employee_data: EmployeeUpdate) -> Optional[Employee]:
        db_employee = await self.get_employee(employee_id)
        if not db_employee:
            return None
        
        update_data = employee_data.model_dump(exclude_unset=True)
        for field, value in update_data.items():
            setattr(db_employee, field, value)
        
        await self.db.commit()
        await self.db.refresh(db_employee)
        return db_employee
    
    async def update_employee_by_employee_id(self, employee_id: str, employee_data: EmployeeUpdate) -> Optional[Employee]:
        db_employee = await self.get_employee_by_employee_id(employee_id)
        if not db_employee:
            return None
        
        update_data = employee_data.model_dump(exclude_unset=True)
        for field, value in update_data.items():
            setattr(db_employee, field, value)
        
        await self.db.commit()
        await self.db.refresh(db_employee)
        return db_employee
    
    async def delete_employee(self, employee_id: int) -> bool:
        db_employee = await self.get_employee(employee_id)
        if not db_employee:
            return False
        
        await self.db.delete(db_employee)
        await self.db.commit()
        return True
    
    async def delete_employee_by_employee_id(self, employee_id: str) -> bool:
        db_employee = await self.get_employee_by_employee_id(employee_id)
        if not db_employee:
            return False
        
        await self.db.delete(db_employee)
        await self.db.commit()
        return True
    
    async def authenticate(self, email: str, password: str) -> Optional[Employee]:
        employee = await self.get_employee_by_email(email)
        if not employee:
            return None
        if not verify_password(password, employee.hashed_password):
            return None
        return employee