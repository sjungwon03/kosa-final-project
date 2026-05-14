FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

ENV FLASK_APP=application.py

EXPOSE 80

CMD ["flask", "run", "--host=0.0.0.0", "--port=80"]
