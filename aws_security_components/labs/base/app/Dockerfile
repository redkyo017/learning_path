# Tiny lab app image — see app.py for what it does and why it is
# deliberately vulnerable. Build and push this to your own ECR repo, then
# point the `app_image` Terraform variable at it. Do not publish this image
# to a public registry.

FROM python:3.12-slim

WORKDIR /app

RUN pip install --no-cache-dir flask==3.0.* requests==2.32.* boto3==1.34.*

COPY app.py .

EXPOSE 8080

CMD ["python", "app.py"]
