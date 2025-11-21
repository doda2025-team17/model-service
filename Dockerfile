FROM python:3.12.9-slim

# Set working directory
WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install -r requirements.txt

# Copy source code and smsspamcollection
COPY src/ ./src/
COPY docker-entrypoint.sh ./docker-entrypoint.sh

RUN chmod +x docker-entrypoint.sh

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV MODEL_SERVICE_PORT=8081
ENV MODEL_DIR="/models"

# Expose port
EXPOSE ${MODEL_SERVICE_PORT}

# Run the model service with bootstrap logic for model fetching
ENTRYPOINT ["/app/docker-entrypoint.sh", "python", "src/serve_model.py"]
