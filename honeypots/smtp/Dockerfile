FROM python:3.11-alpine

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY honeypot.py .

RUN adduser -D -g '' honeypot
USER honeypot

EXPOSE 2525

CMD ["python", "-u", "honeypot.py"]
