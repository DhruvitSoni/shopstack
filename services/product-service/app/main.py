"""Product service: catalog CRUD backed by PostgreSQL, exposes Prometheus metrics."""
import os
import time
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Request, Response
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest
from pydantic import BaseModel

from .db import Database

REQUESTS = Counter(
    "http_requests_total", "Total HTTP requests", ["service", "method", "path", "status"]
)
LATENCY = Histogram(
    "http_request_duration_seconds", "Request latency", ["service", "method", "path"]
)
SERVICE = "product-service"

db = Database(os.getenv("DATABASE_URL", "sqlite:///./products.db"))


@asynccontextmanager
async def lifespan(_: FastAPI):
    db.init()
    yield


app = FastAPI(title="Product Service", version=os.getenv("APP_VERSION", "dev"), lifespan=lifespan)


class ProductIn(BaseModel):
    name: str
    price: float
    stock: int = 0


class Product(ProductIn):
    id: int


@app.middleware("http")
async def metrics_middleware(request: Request, call_next):
    start = time.perf_counter()
    response = await call_next(request)
    route = request.scope.get("route")
    path = route.path if route else "unmatched"
    if path != "/metrics":
        LATENCY.labels(SERVICE, request.method, path).observe(time.perf_counter() - start)
        REQUESTS.labels(SERVICE, request.method, path, response.status_code).inc()
    return response


@app.get("/healthz")
def healthz():
    return {"status": "ok"}


@app.get("/readyz")
def readyz():
    if not db.ping():
        raise HTTPException(503, "database unavailable")
    return {"status": "ready"}


@app.get("/metrics")
def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.get("/api/products", response_model=list[Product])
def list_products():
    return db.list_products()


@app.get("/api/products/{product_id}", response_model=Product)
def get_product(product_id: int):
    p = db.get_product(product_id)
    if not p:
        raise HTTPException(404, "product not found")
    return p


@app.post("/api/products", response_model=Product, status_code=201)
def create_product(body: ProductIn):
    return db.create_product(body.name, body.price, body.stock)


@app.post("/api/products/{product_id}/reserve", response_model=Product)
def reserve(product_id: int, qty: int = 1):
    p = db.reserve(product_id, qty)
    if p is None:
        raise HTTPException(404, "product not found")
    if p is False:
        raise HTTPException(409, "insufficient stock")
    return p
