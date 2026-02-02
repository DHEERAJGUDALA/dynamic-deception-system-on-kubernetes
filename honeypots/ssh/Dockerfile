FROM python:3.11-alpine

WORKDIR /app

# Install minimal dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY honeypot.py .

# Create non-root user
RUN adduser -D -g '' honeypot
USER honeypot

EXPOSE 2222

CMD ["python", "-u", "honeypot.py"]
