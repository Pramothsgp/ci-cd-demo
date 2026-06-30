"""
API Gateway Service - Entry point for the microservices architecture.
Routes requests to user-service and order-service.
"""
import os
import httpx
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from contextlib import asynccontextmanager
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Service URLs from environment variables
USER_SERVICE_URL = os.getenv("USER_SERVICE_URL", "http://user-service:8001")
ORDER_SERVICE_URL = os.getenv("ORDER_SERVICE_URL", "http://order-service:8002")

# HTTP client for service communication
http_client: httpx.AsyncClient = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Manage application lifecycle - startup and shutdown."""
    global http_client
    http_client = httpx.AsyncClient(timeout=30.0)
    logger.info("API Gateway started")
    logger.info(f"User Service URL: {USER_SERVICE_URL}")
    logger.info(f"Order Service URL: {ORDER_SERVICE_URL}")
    yield
    await http_client.aclose()
    logger.info("API Gateway stopped")


app = FastAPI(
    title="API Gateway",
    description="Entry point for the microservices demo",
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


@app.get("/health")
async def health_check():
    """Health check endpoint for Kubernetes probes."""
    return {"status": "healthy", "service": "api-gateway"}


@app.get("/ready")
async def readiness_check():
    """Readiness check - verifies downstream services are reachable."""
    services_status = {}
    
    try:
        user_response = await http_client.get(f"{USER_SERVICE_URL}/health")
        services_status["user-service"] = "healthy" if user_response.status_code == 200 else "unhealthy"
    except Exception as e:
        services_status["user-service"] = f"unreachable: {str(e)}"
    
    try:
        order_response = await http_client.get(f"{ORDER_SERVICE_URL}/health")
        services_status["order-service"] = "healthy" if order_response.status_code == 200 else "unhealthy"
    except Exception as e:
        services_status["order-service"] = f"unreachable: {str(e)}"
    
    all_healthy = all(status == "healthy" for status in services_status.values())
    
    return {
        "status": "ready" if all_healthy else "degraded",
        "service": "api-gateway",
        "downstream_services": services_status
    }


# ==================== USER SERVICE ROUTES ====================

@app.get("/api/users")
async def get_users():
    """Get all users from user-service."""
    try:
        response = await http_client.get(f"{USER_SERVICE_URL}/users")
        return response.json()
    except httpx.RequestError as e:
        logger.error(f"Error connecting to user-service: {e}")
        raise HTTPException(status_code=503, detail="User service unavailable")


@app.get("/api/users/{user_id}")
async def get_user(user_id: int):
    """Get a specific user from user-service."""
    try:
        response = await http_client.get(f"{USER_SERVICE_URL}/users/{user_id}")
        if response.status_code == 404:
            raise HTTPException(status_code=404, detail="User not found")
        return response.json()
    except httpx.RequestError as e:
        logger.error(f"Error connecting to user-service: {e}")
        raise HTTPException(status_code=503, detail="User service unavailable")


@app.post("/api/users")
async def create_user(request: Request):
    """Create a new user via user-service."""
    try:
        body = await request.json()
        response = await http_client.post(f"{USER_SERVICE_URL}/users", json=body)
        return response.json()
    except httpx.RequestError as e:
        logger.error(f"Error connecting to user-service: {e}")
        raise HTTPException(status_code=503, detail="User service unavailable")


@app.put("/api/users/{user_id}")
async def update_user(user_id: int, request: Request):
    """Update a user via user-service."""
    try:
        body = await request.json()
        response = await http_client.put(f"{USER_SERVICE_URL}/users/{user_id}", json=body)
        if response.status_code == 404:
            raise HTTPException(status_code=404, detail="User not found")
        return response.json()
    except httpx.RequestError as e:
        logger.error(f"Error connecting to user-service: {e}")
        raise HTTPException(status_code=503, detail="User service unavailable")


@app.delete("/api/users/{user_id}")
async def delete_user(user_id: int):
    """Delete a user via user-service."""
    try:
        response = await http_client.delete(f"{USER_SERVICE_URL}/users/{user_id}")
        if response.status_code == 404:
            raise HTTPException(status_code=404, detail="User not found")
        return response.json()
    except httpx.RequestError as e:
        logger.error(f"Error connecting to user-service: {e}")
        raise HTTPException(status_code=503, detail="User service unavailable")


# ==================== ORDER SERVICE ROUTES ====================

@app.get("/api/orders")
async def get_orders():
    """Get all orders from order-service."""
    try:
        response = await http_client.get(f"{ORDER_SERVICE_URL}/orders")
        return response.json()
    except httpx.RequestError as e:
        logger.error(f"Error connecting to order-service: {e}")
        raise HTTPException(status_code=503, detail="Order service unavailable")


@app.get("/api/orders/{order_id}")
async def get_order(order_id: int):
    """Get a specific order from order-service."""
    try:
        response = await http_client.get(f"{ORDER_SERVICE_URL}/orders/{order_id}")
        if response.status_code == 404:
            raise HTTPException(status_code=404, detail="Order not found")
        return response.json()
    except httpx.RequestError as e:
        logger.error(f"Error connecting to order-service: {e}")
        raise HTTPException(status_code=503, detail="Order service unavailable")


@app.post("/api/orders")
async def create_order(request: Request):
    """Create a new order via order-service."""
    try:
        body = await request.json()
        response = await http_client.post(f"{ORDER_SERVICE_URL}/orders", json=body)
        if response.status_code == 400:
            return JSONResponse(status_code=400, content=response.json())
        return response.json()
    except httpx.RequestError as e:
        logger.error(f"Error connecting to order-service: {e}")
        raise HTTPException(status_code=503, detail="Order service unavailable")


@app.put("/api/orders/{order_id}/status")
async def update_order_status(order_id: int, request: Request):
    """Update order status via order-service."""
    try:
        body = await request.json()
        response = await http_client.put(f"{ORDER_SERVICE_URL}/orders/{order_id}/status", json=body)
        if response.status_code == 404:
            raise HTTPException(status_code=404, detail="Order not found")
        return response.json()
    except httpx.RequestError as e:
        logger.error(f"Error connecting to order-service: {e}")
        raise HTTPException(status_code=503, detail="Order service unavailable")


@app.get("/api/users/{user_id}/orders")
async def get_user_orders(user_id: int):
    """Get all orders for a specific user."""
    try:
        response = await http_client.get(f"{ORDER_SERVICE_URL}/orders/user/{user_id}")
        return response.json()
    except httpx.RequestError as e:
        logger.error(f"Error connecting to order-service: {e}")
        raise HTTPException(status_code=503, detail="Order service unavailable")


# ==================== AGGREGATED ENDPOINTS ====================

@app.get("/api/dashboard")
async def get_dashboard():
    """Aggregated endpoint - returns users and orders summary."""
    result = {
        "users": {"count": 0, "data": []},
        "orders": {"count": 0, "data": []}
    }
    
    try:
        user_response = await http_client.get(f"{USER_SERVICE_URL}/users")
        if user_response.status_code == 200:
            users = user_response.json()
            result["users"] = {"count": len(users), "data": users}
    except Exception as e:
        logger.warning(f"Could not fetch users: {e}")
    
    try:
        order_response = await http_client.get(f"{ORDER_SERVICE_URL}/orders")
        if order_response.status_code == 200:
            orders = order_response.json()
            result["orders"] = {"count": len(orders), "data": orders}
    except Exception as e:
        logger.warning(f"Could not fetch orders: {e}")
    
    return result


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
