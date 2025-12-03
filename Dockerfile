# Stage 1: Build dependencies
FROM python:3.12.9-slim AS builder

WORKDIR /app

# Install dependencies in a virtual environment
COPY requirements.txt .
RUN python -m venv /opt/venv && \
    /opt/venv/bin/pip install --no-cache-dir -r requirements.txt

# Stage 2: Runtime image (smaller, no build tools)
FROM python:3.12.9-slim

WORKDIR /app

# Copy virtual environment from builder
COPY --from=builder /opt/venv /opt/venv

# Copy application code
COPY src/ ./src/
COPY docker-entrypoint.sh ./docker-entrypoint.sh
RUN chmod +x docker-entrypoint.sh

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV MODEL_SERVICE_PORT=8081
ENV MODEL_DIR="/models"
ENV PATH="/opt/venv/bin:$PATH"

# Expose port
EXPOSE ${MODEL_SERVICE_PORT}

# Run the model service
ENTRYPOINT ["/app/docker-entrypoint.sh", "python", "src/serve_model.py"]