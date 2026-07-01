"""
User Service - Manages user CRUD operations.
"""
import os
from datetime import datetime
from typing import Dict, List, Optional
from fastapi import FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import logging

from .models import User, UserCreate, UserUpdate, UserRole

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# In-memory data store (for demo purposes)
users_db: Dict[int, dict] = {}
user_id_counter: int = 0


def init_sample_data():
    """Initialize with sample data for demonstration."""
    global user_id_counter
    sample_users = [
        {"name": "Pramoth", "email": "alice@example.com", "role": UserRole.ADMIN},
        {"name": "Bob Smith", "email": "bob@example.com", "role": UserRole.USER},
        {"name": "Charlie Brown", "email": "charlie@example.com", "role": UserRole.USER},
    ]
    
    for user_data in sample_users:
        user_id_counter += 1
        now = datetime.utcnow()
        users_db[user_id_counter] = {
            "id": user_id_counter,
            "name": user_data["name"],
            "email": user_data["email"],
            "role": user_data["role"],
            "created_at": now,
            "updated_at": now
        }
    
    logger.info(f"Initialized {len(sample_users)} sample users")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Manage application lifecycle."""
    init_sample_data()
    logger.info("User Service started")
    yield
    logger.info("User Service stopped")


app = FastAPI(
    title="User Service",
    description="Microservice for user management",
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
    return {
        "status": "healthy",
        "service": "user-service",
        "users_count": len(users_db)
    }


@app.get("/ready")
async def readiness_check():
    """Readiness check endpoint."""
    return {
        "status": "ready",
        "service": "user-service"
    }


@app.get("/users", response_model=List[User])
async def get_all_users():
    """Get all users."""
    logger.info(f"Fetching all users. Count: {len(users_db)}")
    return list(users_db.values())


@app.get("/users/{user_id}", response_model=User)
async def get_user(user_id: int):
    """Get a specific user by ID."""
    if user_id not in users_db:
        logger.warning(f"User {user_id} not found")
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"User with id {user_id} not found"
        )
    
    logger.info(f"Fetching user {user_id}")
    return users_db[user_id]


@app.post("/users", response_model=User, status_code=status.HTTP_201_CREATED)
async def create_user(user: UserCreate):
    """Create a new user."""
    global user_id_counter
    
    # Check for duplicate email
    for existing_user in users_db.values():
        if existing_user["email"] == user.email:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"User with email {user.email} already exists"
            )
    
    user_id_counter += 1
    now = datetime.utcnow()
    
    new_user = {
        "id": user_id_counter,
        "name": user.name,
        "email": user.email,
        "role": user.role,
        "created_at": now,
        "updated_at": now
    }
    
    users_db[user_id_counter] = new_user
    logger.info(f"Created user {user_id_counter}: {user.name}")
    
    return new_user


@app.put("/users/{user_id}", response_model=User)
async def update_user(user_id: int, user_update: UserUpdate):
    """Update an existing user."""
    if user_id not in users_db:
        logger.warning(f"User {user_id} not found for update")
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"User with id {user_id} not found"
        )
    
    existing_user = users_db[user_id]
    update_data = user_update.model_dump(exclude_unset=True)
    
    # Check for duplicate email if email is being updated
    if "email" in update_data:
        for uid, u in users_db.items():
            if uid != user_id and u["email"] == update_data["email"]:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"User with email {update_data['email']} already exists"
                )
    
    for field, value in update_data.items():
        existing_user[field] = value
    
    existing_user["updated_at"] = datetime.utcnow()
    
    logger.info(f"Updated user {user_id}")
    return existing_user


@app.delete("/users/{user_id}")
async def delete_user(user_id: int):
    """Delete a user."""
    if user_id not in users_db:
        logger.warning(f"User {user_id} not found for deletion")
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"User with id {user_id} not found"
        )
    
    deleted_user = users_db.pop(user_id)
    logger.info(f"Deleted user {user_id}: {deleted_user['name']}")
    
    return {"message": f"User {user_id} deleted successfully", "user": deleted_user}


@app.get("/users/{user_id}/exists")
async def check_user_exists(user_id: int):
    """Check if a user exists (used by other services)."""
    exists = user_id in users_db
    return {"user_id": user_id, "exists": exists}


# Metrics endpoint for Prometheus
@app.get("/metrics")
async def metrics():
    """Basic metrics endpoint for monitoring."""
    return {
        "total_users": len(users_db),
        "users_by_role": {
            "admin": sum(1 for u in users_db.values() if u["role"] == UserRole.ADMIN),
            "user": sum(1 for u in users_db.values() if u["role"] == UserRole.USER),
            "guest": sum(1 for u in users_db.values() if u["role"] == UserRole.GUEST),
        }
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)
