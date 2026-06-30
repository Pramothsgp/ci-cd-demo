"""
Pydantic models for User Service.
"""
from pydantic import BaseModel, EmailStr, Field
from typing import Optional
from datetime import datetime
from enum import Enum


class UserRole(str, Enum):
    """User roles enumeration."""
    ADMIN = "admin"
    USER = "user"
    GUEST = "guest"


class UserBase(BaseModel):
    """Base user model with common fields."""
    name: str = Field(..., min_length=1, max_length=100, description="User's full name")
    email: str = Field(..., description="User's email address")
    role: UserRole = Field(default=UserRole.USER, description="User's role")


class UserCreate(UserBase):
    """Model for creating a new user."""
    pass


class UserUpdate(BaseModel):
    """Model for updating an existing user."""
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    email: Optional[str] = None
    role: Optional[UserRole] = None


class User(UserBase):
    """Complete user model with all fields."""
    id: int = Field(..., description="Unique user identifier")
    created_at: datetime = Field(..., description="User creation timestamp")
    updated_at: datetime = Field(..., description="Last update timestamp")
    
    class Config:
        from_attributes = True


class UserResponse(BaseModel):
    """Response wrapper for user operations."""
    message: str
    user: Optional[User] = None
