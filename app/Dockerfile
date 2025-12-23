FROM python:3.12

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py .
EXPOSE 8080

# ✅ create non-root user
RUN useradd -m -u 10001 appuser \
    && chown -R 10001:10001 /app
USER 10001

CMD ["python", "main.py"]