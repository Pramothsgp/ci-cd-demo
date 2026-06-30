"""Tests for User Service."""
import pytest
from fastapi.testclient import TestClient
import sys
sys.path.insert(0, '..')
from app.main import app, users_db, user_id_counter


@pytest.fixture
def client():
    """Create test client."""
    return TestClient(app)


@pytest.fixture(autouse=True)
def reset_db():
    """Reset the database before each test."""
    global user_id_counter
    users_db.clear()
    user_id_counter = 0
    yield
    users_db.clear()


class TestHealthEndpoints:
    """Test health and readiness endpoints."""
    
    def test_health_check(self, client):
        """Test health endpoint."""
        response = client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert data["service"] == "user-service"
    
    def test_readiness_check(self, client):
        """Test readiness endpoint."""
        response = client.get("/ready")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "ready"


class TestUserCRUD:
    """Test user CRUD operations."""
    
    def test_get_all_users_empty(self, client):
        """Test getting users when database is empty."""
        response = client.get("/users")
        assert response.status_code == 200
        assert response.json() == []
    
    def test_create_user(self, client):
        """Test creating a new user."""
        user_data = {
            "name": "Test User",
            "email": "test@example.com",
            "role": "user"
        }
        response = client.post("/users", json=user_data)
        assert response.status_code == 201
        data = response.json()
        assert data["name"] == "Test User"
        assert data["email"] == "test@example.com"
        assert "id" in data
    
    def test_get_user(self, client):
        """Test getting a specific user."""
        # First create a user
        user_data = {"name": "Test User", "email": "test@example.com"}
        create_response = client.post("/users", json=user_data)
        user_id = create_response.json()["id"]
        
        # Then get the user
        response = client.get(f"/users/{user_id}")
        assert response.status_code == 200
        assert response.json()["name"] == "Test User"
    
    def test_get_nonexistent_user(self, client):
        """Test getting a user that doesn't exist."""
        response = client.get("/users/999")
        assert response.status_code == 404
    
    def test_update_user(self, client):
        """Test updating a user."""
        # Create a user
        user_data = {"name": "Original Name", "email": "test@example.com"}
        create_response = client.post("/users", json=user_data)
        user_id = create_response.json()["id"]
        
        # Update the user
        update_data = {"name": "Updated Name"}
        response = client.put(f"/users/{user_id}", json=update_data)
        assert response.status_code == 200
        assert response.json()["name"] == "Updated Name"
    
    def test_delete_user(self, client):
        """Test deleting a user."""
        # Create a user
        user_data = {"name": "Test User", "email": "test@example.com"}
        create_response = client.post("/users", json=user_data)
        user_id = create_response.json()["id"]
        
        # Delete the user
        response = client.delete(f"/users/{user_id}")
        assert response.status_code == 200
        
        # Verify user is deleted
        get_response = client.get(f"/users/{user_id}")
        assert get_response.status_code == 404
    
    def test_duplicate_email(self, client):
        """Test that duplicate emails are rejected."""
        user_data = {"name": "User 1", "email": "same@example.com"}
        client.post("/users", json=user_data)
        
        user_data2 = {"name": "User 2", "email": "same@example.com"}
        response = client.post("/users", json=user_data2)
        assert response.status_code == 400


class TestUserExists:
    """Test user exists endpoint."""
    
    def test_user_exists(self, client):
        """Test checking if user exists."""
        # Create a user
        user_data = {"name": "Test User", "email": "test@example.com"}
        create_response = client.post("/users", json=user_data)
        user_id = create_response.json()["id"]
        
        # Check exists
        response = client.get(f"/users/{user_id}/exists")
        assert response.status_code == 200
        assert response.json()["exists"] == True
    
    def test_user_not_exists(self, client):
        """Test checking if nonexistent user exists."""
        response = client.get("/users/999/exists")
        assert response.status_code == 200
        assert response.json()["exists"] == False


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
