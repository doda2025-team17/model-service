# SMS Checker / Backend

The backend of this project provides a simple REST service that can be used to detect spam messages.
We have extended the base project [rohan8594/SMS-Spam-Detection](https://github.com/rohan8594/SMS-Spam-Detection), which introduces several basic classification models, and wrap one of them in a microservice.

The following sections will explain you how to get started.
The project **requires a Python 3.12 environment** to run (tested with 3.12.9).
Use the `requirements.txt` file to restore the required dependencies in your environment.


### Training the Model

To train the model, you have two options.
Either you create a local environment...

    $ python -m venv venv
    $ source venv/bin/activate
    $ pip install -r requirements.txt

... or you train in a Docker container (recommended):

    $ docker run -it --rm -v ./:/root/sms/ python:3.12.9-slim bash
    ... (container startup)
    $ cd /root/sms/
    $ pip install -r requirements.txt

Once all dependencies have been installed, the data can be preprocessed and the model trained by creating the output folder and invoking three commands:

    $ mkdir output
    $ python src/read_data.py
    Total number of messages:5574
    ...
    $ python src/text_preprocessing.py
    [nltk_data] Downloading package stopwords to /root/nltk_data...
    [nltk_data]   Unzipping corpora/stopwords.zip.
    ...
    $ python src/text_classification.py

The resulting model files will be placed as `.joblib` files in the `output/` folder.

### Automated Training & Release

This repository includes a GitHub Actions workflow named **Train and Release Model** that retrains the classifier on demand and publishes the resulting artifacts as public assets on a GitHub release.

- Trigger it via **Actions → Train and Release Model → Run workflow**, provide a `model_version` (e.g., `v1.0.0`) plus optional release notes, and the workflow will install dependencies, execute `scripts/train_and_package.sh`, and upload everything from `dist/` to a release tagged with that version.
- You can also run `scripts/train_and_package.sh <model_version>` locally (or set `MODEL_VERSION=<version>`) to regenerate the artifacts and preview what will be uploaded.
- Once the workflow completes, download the model, preprocessor, and supporting files from the release page that matches the provided version tag.

### Model artifacts and runtime location

- At runtime the service loads `model.joblib` (classifier) and `preprocessor.joblib` (vectorizer pipeline) from `${MODEL_DIR:-/models}`. Both files must exist for the service to start.
- Mount a volume to `/models` (or set `MODEL_DIR`) containing those two files. Optional extras (e.g., `misclassified_msgs.txt`, `accuracy_scores.png`) are not required to serve predictions.
- Environment knobs:
  - `MODEL_DIR` (default `/models`): where the service looks for model artifacts.
  - `MODEL_FILES` (default `model.joblib,preprocessor.joblib`): comma-separated list of required files that must exist in `MODEL_DIR`.
  - `MODEL_URL` (optional): public URL to a bundle (e.g., .zip/.tar.gz) containing the required files.
- Startup behavior: on each boot, the service checks for all files in `MODEL_FILES` under `MODEL_DIR`. If any are missing and `MODEL_URL` is set, it downloads the bundle once, extracts it into `MODEL_DIR`, and proceeds. If files are still missing (or `MODEL_URL` is unset), the service will fail fast with a clear error.
- Container defaults: the image sets `MODEL_DIR=/models` and uses a simple entrypoint that prepares the directory and starts the app; mount your model artifacts to `/models` or supply `MODEL_URL` to fetch them on first boot.

### Serving Recommendations

To make the models accessible, you need to start the microservice by running the `src/serve_model.py` script from within the virtual environment that you created before, or in a fresh Docker container (recommended):

    $ docker run -it --rm -p 8081:8081 -v ./:/root/sms/ python:3.12.9-slim bash
    ... (container startup)
    $ cd /root/sms/
    $ pip install -r requirements.txt
    $ python src/serve_model.py

The server will start on port 8081.
Once its startup has finished, you can either access [localhost:8081/apidocs](http://localhost:8081/apidocs) in your browser to interact with the service, or you send `POST` requests to request predictions, for example with `curl`:


    $ curl -X POST "http://localhost:8081/predict" -H "Content-Type: application/json" -d '{"sms": "test ..."}'
    {
      "classifier": "decision tree",
      "result": "ham",
      "sms": "test ..."
    }
