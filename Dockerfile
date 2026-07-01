FROM python:3.12-slim

WORKDIR /app

RUN apt-get update && apt-get install -y \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY package.json package-lock.json* ./
RUN npm install

COPY . .

RUN npm run build
RUN python manage.py collectstatic --noinput

EXPOSE 8000

CMD ["gunicorn", "notesy.wsgi:application", "--bind", "0.0.0.0:8000"]