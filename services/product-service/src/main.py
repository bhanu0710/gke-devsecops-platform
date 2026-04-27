"""
product-service — FastAPI product catalog microservice.
Demonstrates Python FastAPI patterns, Prometheus instrumentation, and
OpenTelemetry tracing alongside the Node.js services.
"""
import os
import uuid
from datetime import datetime
from typing import Optional

from fastapi import FastAPI, HTTPException, status
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.sdk.resources import SERVICE_NAME, Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from prometheus_fastapi_instrumentator import Instrumentator
from pydantic import BaseModel, Field

# ── OpenTelemetry setup ───────────────────────────────────────────────────────
# Set up tracing before creating the FastAPI app so the FastAPIInstrumentor
# can attach to the tracer provider during instrumentation.
OTLP_ENDPOINT = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector.monitoring:4317")

resource = Resource(attributes={SERVICE_NAME: "product-service"})
provider = TracerProvider(resource=resource)
provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter(endpoint=OTLP_ENDPOINT, insecure=True)))
trace.set_tracer_provider(provider)
tracer = trace.get_tracer(__name__)

VERSION = os.getenv("VERSION", "1.0.0")

# ── In-memory store ───────────────────────────────────────────────────────────
# Dict keyed by product ID — same rationale as user-service (no DB dependency).
_products: dict[str, dict] = {}


def _seed():
    """Seed with sample data so the service has content on first start."""
    for item in [
        {"name": "Laptop Pro X1", "price": 999.99, "category": "electronics", "stock": 50},
        {"name": "Wireless Headphones", "price": 79.99, "category": "electronics", "stock": 200},
        {"name": "Coffee Maker 3000", "price": 49.99, "category": "appliances", "stock": 30},
    ]:
        pid = str(uuid.uuid4())
        _products[pid] = {**item, "id": pid, "created_at": datetime.utcnow().isoformat()}


_seed()

# ── Pydantic schemas ──────────────────────────────────────────────────────────

class ProductCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=200)
    price: float = Field(..., gt=0)
    category: str
    stock: int = Field(default=0, ge=0)


class ProductUpdate(BaseModel):
    name: Optional[str] = None
    price: Optional[float] = Field(default=None, gt=0)
    category: Optional[str] = None
    stock: Optional[int] = Field(default=None, ge=0)


# ── FastAPI app ───────────────────────────────────────────────────────────────

app = FastAPI(title="product-service", version=VERSION, docs_url="/docs")

# Auto-instrument all FastAPI routes for tracing
FastAPIInstrumentor.instrument_app(app)

# Expose /metrics endpoint for Prometheus scraping
# expose=True mounts the endpoint on the app itself (no separate port needed)
Instrumentator().instrument(app).expose(app)


# ── Routes ────────────────────────────────────────────────────────────────────

@app.get("/health")
def health():
    return {"status": "ok", "service": "product-service", "version": VERSION}


@app.get("/ready")
def ready():
    return {"status": "ready"}


@app.get("/products")
def list_products(category: Optional[str] = None, limit: int = 50):
    products = list(_products.values())
    if category:
        products = [p for p in products if p["category"] == category]
    return {"products": products[:limit], "total": len(products)}


@app.post("/products", status_code=status.HTTP_201_CREATED)
def create_product(body: ProductCreate):
    pid = str(uuid.uuid4())
    product = {
        "id": pid,
        "created_at": datetime.utcnow().isoformat(),
        **body.model_dump(),
    }
    _products[pid] = product
    # Add custom span attribute so this specific product creation appears
    # in distributed traces when order-service calls us
    with tracer.start_as_current_span("product.create") as span:
        span.set_attribute("product.id", pid)
        span.set_attribute("product.name", body.name)
    return product


@app.get("/products/{product_id}")
def get_product(product_id: str):
    product = _products.get(product_id)
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    return product


@app.put("/products/{product_id}")
def update_product(product_id: str, body: ProductUpdate):
    product = _products.get(product_id)
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    updates = {k: v for k, v in body.model_dump().items() if v is not None}
    product.update({**updates, "updated_at": datetime.utcnow().isoformat()})
    _products[product_id] = product
    return product


@app.delete("/products/{product_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_product(product_id: str):
    if product_id not in _products:
        raise HTTPException(status_code=404, detail="Product not found")
    del _products[product_id]
