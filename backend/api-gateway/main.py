from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
import httpx

from shared.config import settings

app = FastAPI(title="KOSA API Gateway", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "api-gateway"}


@app.api_route("/employee/{path:path}", methods=["GET", "POST", "PUT", "DELETE"])
async def employee_proxy(path: str, request: Request):
    async with httpx.AsyncClient() as client:
        url = f"{settings.employee_service_url}/{path}"
        
        headers = dict(request.headers)
        headers.pop("host", None)
        headers.pop("content-length", None)
        headers.pop("content-type", None)
        
        if request.method == "GET":
            response = await client.get(url, params=request.query_params, headers=headers, follow_redirects=True)
        elif request.method == "POST":
            body = await request.json()
            response = await client.post(url, json=body, headers=headers, follow_redirects=True)
        elif request.method == "PUT":
            body = await request.json()
            response = await client.put(url, json=body, headers=headers, follow_redirects=True)
        elif request.method == "DELETE":
            response = await client.delete(url, headers=headers, follow_redirects=True)
        
        return response.json()


@app.api_route("/welfare/{path:path}", methods=["GET", "POST", "PUT", "DELETE"])
async def welfare_proxy(path: str, request: Request):
    async with httpx.AsyncClient() as client:
        url = f"{settings.welfare_service_url}/{path}"
        
        headers = dict(request.headers)
        headers.pop("host", None)
        headers.pop("content-length", None)
        headers.pop("content-type", None)
        
        if request.method == "GET":
            response = await client.get(url, params=request.query_params, headers=headers, follow_redirects=True)
        elif request.method == "POST":
            body = await request.json()
            response = await client.post(url, json=body, headers=headers, follow_redirects=True)
        elif request.method == "PUT":
            body = await request.json()
            response = await client.put(url, json=body, headers=headers, follow_redirects=True)
        elif request.method == "DELETE":
            response = await client.delete(url, headers=headers, follow_redirects=True)
        
        return response.json()


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host=settings.api_gateway_host,
        port=settings.api_gateway_port,
        reload=settings.env == "development"
    )