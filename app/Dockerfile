FROM python:3.12-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py .
EXPOSE 8080

# ✅ create non-root user
RUN useradd -m -u 10001 appuser
USER 10001

CMD ["python", "main.py"]