"""
Flask API of the SMS Spam detection model model.
"""
import os
import shutil
import tarfile
import tempfile
import zipfile
import joblib
import urllib.request
from flask import Flask, jsonify, request
from flasgger import Swagger
import pandas as pd

from text_preprocessing import prepare, _extract_message_len, _text_process

app = Flask(__name__)
swagger = Swagger(app)
MODEL_DIR = os.getenv('MODEL_DIR', '/models')
# Optional: URL to a public bundle containing model artifacts (e.g., .tar.gz or .zip)
MODEL_URL = os.getenv('MODEL_URL', '')
# Comma-separated list of required model artifacts; defaults cover serving needs.
MODEL_FILES = [f.strip() for f in os.getenv('MODEL_FILES', 'model.joblib,preprocessor.joblib').split(',') if f.strip()]

def _model_path(filename: str) -> str:
    return os.path.join(MODEL_DIR, filename)

def _missing_model_files():
    return [f for f in MODEL_FILES if not os.path.exists(_model_path(f))]

def _assert_required_model_files():
    missing = _missing_model_files()
    if missing:
        raise FileNotFoundError(
            f"Missing model artifacts in '{MODEL_DIR}': {', '.join(missing)}. "
            "Ensure the models volume contains the required files or update MODEL_DIR/MODEL_FILES."
        )

def _maybe_download_model_bundle():
    """
    If MODEL_URL is provided and required files are missing in MODEL_DIR, download and unpack once.
    Supports .tar(.gz/.bz2/.xz) and .zip archives. For a single required file, a raw download is accepted.
    """
    os.makedirs(MODEL_DIR, exist_ok=True)
    if not _missing_model_files():
        return
    if not MODEL_URL:
        return

    fd, tmp_path = tempfile.mkstemp()
    os.close(fd)
    try:
        print(f"Downloading model bundle from {MODEL_URL} ...")
        urllib.request.urlretrieve(MODEL_URL, tmp_path)

        if tarfile.is_tarfile(tmp_path):
            with tarfile.open(tmp_path) as tar:
                tar.extractall(MODEL_DIR)
        elif zipfile.is_zipfile(tmp_path):
            with zipfile.ZipFile(tmp_path) as zf:
                zf.extractall(MODEL_DIR)
        else:
            # Fallback: if only one file is expected, treat the download as that file
            if len(MODEL_FILES) == 1:
                shutil.move(tmp_path, _model_path(MODEL_FILES[0]))
                tmp_path = None  # moved
            else:
                raise RuntimeError(
                    "MODEL_URL did not point to a supported archive (.tar/.gz/.zip), "
                    "and multiple model files are required."
                )
    finally:
        if tmp_path and os.path.exists(tmp_path):
            os.remove(tmp_path)

# Bootstrap model availability once at startup
_maybe_download_model_bundle()
_assert_required_model_files()

def _load_model():
    path = _model_path('model.joblib')
    if not os.path.exists(path):
        raise FileNotFoundError(
            f"Model not found at '{path}'. Ensure the models volume contains model.joblib or set MODEL_DIR accordingly."
        )
    return joblib.load(path)

@app.route('/predict', methods=['POST'])
def predict():
    """
    Predict whether an SMS is Spam.
    ---
    consumes:
      - application/json
    parameters:
        - name: input_data
          in: body
          description: message to be classified.
          required: True
          schema:
            type: object
            required: sms
            properties:
                sms:
                    type: string
                    example: This is an example of an SMS.
    responses:
      200:
        description: "The result of the classification: 'spam' or 'ham'."
    """
    input_data = request.get_json()
    sms = input_data.get('sms')
    processed_sms = prepare(sms)
    model = _load_model()
    prediction = model.predict(processed_sms)[0]
    
    res = {
        "result": prediction,
        "classifier": "decision tree",
        "sms": sms
    }
    print(res)
    return jsonify(res)

if __name__ == '__main__':
    #clf = joblib.load('output/model.joblib')
    port = int(os.getenv('PORT', 8081)) # Read PORT from ENV, default 8081
    app.run(host="0.0.0.0", port=port, debug=True)
