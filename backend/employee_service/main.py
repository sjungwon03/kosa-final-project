from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from employee_service.routes import router as employee_router

app = FastAPI(title="KOSA Employee Service", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(employee_router, prefix="/api/v1/employees", tags=["employees"])


@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "employee_service"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8001, reload=True)