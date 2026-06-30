"""
Order Service - Manages order operations with user validation.
"""
import os
from datetime import datetime
from typing import Dict, List
from fastapi import FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import httpx
import logging

from .models import Order, OrderCreate, OrderStatus, OrderStatusUpdate, OrderItem

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# User service URL for validation
USER_SERVICE_URL = os.getenv("USER_SERVICE_URL", "http://user-service:8001")

# In-memory data store
orders_db: Dict[int, dict] = {}
order_id_counter: int = 0

# HTTP client for service communication
http_client: httpx.AsyncClient = None


def init_sample_data():
    """Initialize with sample orders."""
    global order_id_counter
    sample_orders = [
        {
            "user_id": 1,
            "items": [
                {"product_name": "Laptop", "quantity": 1, "unit_price": 999.99},
                {"product_name": "Mouse", "quantity": 2, "unit_price": 29.99}
            ],
            "shipping_address": "123 Main St, City, Country",
            "status": OrderStatus.DELIVERED
        },
        {
            "user_id": 2,
            "items": [
                {"product_name": "Keyboard", "quantity": 1, "unit_price": 79.99}
            ],
            "shipping_address": "456 Oak Ave, Town, Country",
            "status": OrderStatus.PROCESSING
        },
        {
            "user_id": 1,
            "items": [
                {"product_name": "Monitor", "quantity": 2, "unit_price": 299.99},
                {"product_name": "HDMI Cable", "quantity": 2, "unit_price": 15.99}
            ],
            "shipping_address": "123 Main St, City, Country",
            "status": OrderStatus.PENDING
        }
    ]
    
    for order_data in sample_orders:
        order_id_counter += 1
        now = datetime.utcnow()
        items = [OrderItem(**item) for item in order_data["items"]]
        total = sum(item.quantity * item.unit_price for item in items)
        
        orders_db[order_id_counter] = {
            "id": order_id_counter,
            "user_id": order_data["user_id"],
            "items": order_data["items"],
            "shipping_address": order_data["shipping_address"],
            "status": order_data["status"],
            "total_amount": round(total, 2),
            "created_at": now,
            "updated_at": now
        }
    
    logger.info(f"Initialized {len(sample_orders)} sample orders")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Manage application lifecycle."""
    global http_client
    http_client = httpx.AsyncClient(timeout=10.0)
    init_sample_data()
    logger.info("Order Service started")
    logger.info(f"User Service URL: {USER_SERVICE_URL}")
    yield
    await http_client.aclose()
    logger.info("Order Service stopped")


app = FastAPI(
    title="Order Service",
    description="Microservice for order management",
    version="1.0.0",
    lifespan=lifespan
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


async def validate_user(user_id: int) -> bool:
    """Validate that a user exists by calling user-service."""
    try:
        response = await http_client.get(f"{USER_SERVICE_URL}/users/{user_id}/exists")
        if response.status_code == 200:
            return response.json().get("exists", False)
        return False
    except Exception as e:
        logger.warning(f"Could not validate user {user_id}: {e}")
        # In a real system, you might want to fail closed
        # For demo, we'll allow if user service is unavailable
        return True


@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {
        "status": "healthy",
        "service": "order-service",
        "orders_count": len(orders_db)
    }


@app.get("/ready")
async def readiness_check():
    """Readiness check - verifies user-service is reachable."""
    try:
        response = await http_client.get(f"{USER_SERVICE_URL}/health")
        user_service_healthy = response.status_code == 200
    except Exception:
        user_service_healthy = False
    
    return {
        "status": "ready" if user_service_healthy else "degraded",
        "service": "order-service",
        "user_service": "reachable" if user_service_healthy else "unreachable"
    }


@app.get("/orders", response_model=List[Order])
async def get_all_orders():
    """Get all orders."""
    logger.info(f"Fetching all orders. Count: {len(orders_db)}")
    return list(orders_db.values())


@app.get("/orders/{order_id}", response_model=Order)
async def get_order(order_id: int):
    """Get a specific order by ID."""
    if order_id not in orders_db:
        logger.warning(f"Order {order_id} not found")
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Order with id {order_id} not found"
        )
    
    logger.info(f"Fetching order {order_id}")
    return orders_db[order_id]


@app.get("/orders/user/{user_id}", response_model=List[Order])
async def get_user_orders(user_id: int):
    """Get all orders for a specific user."""
    user_orders = [o for o in orders_db.values() if o["user_id"] == user_id]
    logger.info(f"Fetching orders for user {user_id}. Found: {len(user_orders)}")
    return user_orders


@app.post("/orders", response_model=Order, status_code=status.HTTP_201_CREATED)
async def create_order(order: OrderCreate):
    """Create a new order with user validation."""
    global order_id_counter
    
    # Validate user exists
    user_exists = await validate_user(order.user_id)
    if not user_exists:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"User with id {order.user_id} does not exist"
        )
    
    order_id_counter += 1
    now = datetime.utcnow()
    
    # Calculate total
    items_data = [item.model_dump() for item in order.items]
    total = sum(item["quantity"] * item["unit_price"] for item in items_data)
    
    new_order = {
        "id": order_id_counter,
        "user_id": order.user_id,
        "items": items_data,
        "shipping_address": order.shipping_address,
        "status": OrderStatus.PENDING,
        "total_amount": round(total, 2),
        "created_at": now,
        "updated_at": now
    }
    
    orders_db[order_id_counter] = new_order
    logger.info(f"Created order {order_id_counter} for user {order.user_id}. Total: ${total:.2f}")
    
    return new_order


@app.put("/orders/{order_id}/status", response_model=Order)
async def update_order_status(order_id: int, status_update: OrderStatusUpdate):
    """Update the status of an order."""
    if order_id not in orders_db:
        logger.warning(f"Order {order_id} not found for status update")
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Order with id {order_id} not found"
        )
    
    order = orders_db[order_id]
    old_status = order["status"]
    order["status"] = status_update.status
    order["updated_at"] = datetime.utcnow()
    
    logger.info(f"Updated order {order_id} status: {old_status} -> {status_update.status}")
    return order


@app.delete("/orders/{order_id}")
async def cancel_order(order_id: int):
    """Cancel an order (set status to cancelled)."""
    if order_id not in orders_db:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Order with id {order_id} not found"
        )
    
    order = orders_db[order_id]
    
    if order["status"] in [OrderStatus.SHIPPED, OrderStatus.DELIVERED]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot cancel order that has been shipped or delivered"
        )
    
    order["status"] = OrderStatus.CANCELLED
    order["updated_at"] = datetime.utcnow()
    
    logger.info(f"Cancelled order {order_id}")
    return {"message": f"Order {order_id} cancelled successfully", "order": order}


# Metrics endpoint for Prometheus
@app.get("/metrics")
async def metrics():
    """Basic metrics endpoint for monitoring."""
    status_counts = {}
    for status_val in OrderStatus:
        status_counts[status_val.value] = sum(
            1 for o in orders_db.values() if o["status"] == status_val
        )
    
    total_revenue = sum(o["total_amount"] for o in orders_db.values())
    
    return {
        "total_orders": len(orders_db),
        "orders_by_status": status_counts,
        "total_revenue": round(total_revenue, 2)
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8002)
