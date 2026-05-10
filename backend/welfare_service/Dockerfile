FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y gcc curl && rm -rf /var/lib/apt/lists/*

COPY pyproject.toml ./

RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:$PATH"
RUN uv pip install --system fastapi uvicorn[standard] pydantic[email] pydantic-settings sqlalchemy aiomysql httpx python-jose[cryptography] passlib[bcrypt] bcrypt python-multipart redis email-validator

COPY . .

EXPOSE 8002

CMD ["python", "-m", "uvicorn", "welfare_service.main:app", "--host", "0.0.0.0", "--port", "8002"]