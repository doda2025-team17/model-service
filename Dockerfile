FROM python:3.12.9-slim

# Set working directory
WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install -r requirements.txt

# Copy source code and smsspamcollection
COPY src/ ./src/
COPY smsspamcollection/ ./smsspamcollection/

# Create output directory
RUN mkdir -p output

# Train the model during build
RUN python src/read_data.py && \
    python src/text_preprocessing.py && \
    python src/text_classification.py

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV PORT=8081

# Expose port
EXPOSE ${PORT}

# Run the model service
ENTRYPOINT ["python"]
CMD ["src/serve_model.py"]