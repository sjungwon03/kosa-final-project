from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from welfare_service.routes import router as welfare_router

app = FastAPI(title="KOSA Welfare Service", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(welfare_router, prefix="/api/v1", tags=["welfare"])


@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "welfare-service"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8002, reload=True)