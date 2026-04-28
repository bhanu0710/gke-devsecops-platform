"""Tests for product-service. Uses TestClient (sync) to avoid async complexity."""
import pytest
from fastapi.testclient import TestClient
from unittest.mock import patch

# Patch OpenTelemetry before importing main to avoid real gRPC connections in tests
with patch("opentelemetry.sdk.trace.export.BatchSpanProcessor.on_start"), \
     patch("opentelemetry.exporter.otlp.proto.grpc.trace_exporter.OTLPSpanExporter.__init__", return_value=None):
    from src.main import app, _products

client = TestClient(app)


@pytest.fixture(autouse=True)
def reset_products():
    """Restore seed data before each test."""
    _products.clear()
    from src.main import _seed
    _seed()


class TestHealth:
    def test_returns_ok(self):
        res = client.get("/health")
        assert res.status_code == 200
        assert res.json()["status"] == "ok"
        assert res.json()["service"] == "product-service"

    def test_ready_returns_200(self):
        assert client.get("/ready").status_code == 200


class TestListProducts:
    def test_returns_all_seeded_products(self):
        res = client.get("/products")
        assert res.status_code == 200
        assert res.json()["total"] >= 3

    def test_filter_by_category(self):
        res = client.get("/products?category=electronics")
        assert res.status_code == 200
        for p in res.json()["products"]:
            assert p["category"] == "electronics"


class TestCreateProduct:
    def test_creates_product(self):
        res = client.post("/products", json={
            "name": "Test Widget", "price": 9.99, "category": "misc", "stock": 10
        })
        assert res.status_code == 201
        assert res.json()["id"] is not None
        assert res.json()["name"] == "Test Widget"

    def test_rejects_negative_price(self):
        res = client.post("/products", json={
            "name": "Bad", "price": -1, "category": "misc"
        })
        assert res.status_code == 422


class TestGetProduct:
    def test_returns_product_by_id(self):
        create = client.post("/products", json={
            "name": "Findable", "price": 5.0, "category": "test"
        })
        pid = create.json()["id"]
        res = client.get(f"/products/{pid}")
        assert res.status_code == 200
        assert res.json()["id"] == pid

    def test_returns_404_for_missing(self):
        assert client.get("/products/does-not-exist").status_code == 404


class TestUpdateProduct:
    def test_updates_price(self):
        create = client.post("/products", json={
            "name": "Old Name", "price": 1.0, "category": "test"
        })
        pid = create.json()["id"]
        res = client.put(f"/products/{pid}", json={"price": 2.5})
        assert res.status_code == 200
        assert res.json()["price"] == 2.5
