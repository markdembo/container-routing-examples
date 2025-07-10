# First stage: Install Node.js
FROM node:20-slim AS node_builder
WORKDIR /app
COPY time-service.js .

# Second stage: Python and final image
FROM python:3.11-slim

# Install Node.js
RUN apt-get update && apt-get install -y curl \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy Python requirements and install
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY . .

# Copy Node.js service from first stage
COPY --from=node_builder /app/time-service.js .

# Expose both ports
EXPOSE 8080 8081

# Use a script to start both services
RUN echo '#!/bin/sh\n\
python -u app.py &\
node time-service.js\n' > /app/start_services.sh && \
    chmod +x /app/start_services.sh

CMD ["/app/start_services.sh"]