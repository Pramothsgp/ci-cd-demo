"""
Pydantic models for Order Service.
"""
from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime
from enum import Enum


class OrderStatus(str, Enum):
    """Order status enumeration."""
    PENDING = "pending"
    CONFIRMED = "confirmed"
    PROCESSING = "processing"
    SHIPPED = "shipped"
    DELIVERED = "delivered"
    CANCELLED = "cancelled"


class OrderItem(BaseModel):
    """Individual item in an order."""
    product_name: str = Field(..., min_length=1, max_length=200)
    quantity: int = Field(..., ge=1)
    unit_price: float = Field(..., ge=0)
    
    @property
    def total_price(self) -> float:
        return self.quantity * self.unit_price


class OrderItemCreate(BaseModel):
    """Model for creating order items."""
    product_name: str = Field(..., min_length=1, max_length=200)
    quantity: int = Field(..., ge=1)
    unit_price: float = Field(..., ge=0)


class OrderBase(BaseModel):
    """Base order model."""
    user_id: int = Field(..., description="ID of the user placing the order")
    items: List[OrderItemCreate] = Field(..., min_length=1)
    shipping_address: str = Field(..., min_length=1, max_length=500)


class OrderCreate(OrderBase):
    """Model for creating a new order."""
    pass


class OrderStatusUpdate(BaseModel):
    """Model for updating order status."""
    status: OrderStatus


class Order(BaseModel):
    """Complete order model."""
    id: int
    user_id: int
    items: List[OrderItem]
    shipping_address: str
    status: OrderStatus
    total_amount: float
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True


class OrderResponse(BaseModel):
    """Response wrapper for order operations."""
    message: str
    order: Optional[Order] = None
