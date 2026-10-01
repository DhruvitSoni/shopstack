import os

os.environ["DATABASE_URL"] = "sqlite:///./test_products.db"

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from app.main import app  # noqa: E402


@pytest.fixture(scope="module")
def client():
    if os.path.exists("test_products.db"):
        os.remove("test_products.db")
    with TestClient(app) as c:
        yield c
    os.remove("test_products.db")


def test_health(client):
    assert client.get("/healthz").json() == {"status": "ok"}
    assert client.get("/readyz").status_code == 200


def test_seeded_products(client):
    r = client.get("/api/products")
    assert r.status_code == 200
    assert len(r.json()) >= 3


def test_create_and_reserve(client):
    p = client.post("/api/products", json={"name": "Valve", "price": 10, "stock": 2}).json()
    assert client.post(f"/api/products/{p['id']}/reserve?qty=2").json()["stock"] == 0
    assert client.post(f"/api/products/{p['id']}/reserve").status_code == 409
    assert client.post("/api/products/99999/reserve").status_code == 404


def test_metrics(client):
    body = client.get("/metrics").text
    assert "http_requests_total" in body
