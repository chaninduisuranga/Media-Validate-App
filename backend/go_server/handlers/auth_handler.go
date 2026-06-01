package handlers

import (
	"context"
	"net/http"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/labstack/echo/v4"
	"github.com/mediavalidate/go_server/models"
	"golang.org/x/crypto/bcrypt"
)

var DBPool *pgxpool.Pool

func InitDB(pool *pgxpool.Pool) {
	DBPool = pool
	// Create users table
	userTable := `
	CREATE TABLE IF NOT EXISTS users (
		id BIGSERIAL PRIMARY KEY,
		created_at TIMESTAMPTZ DEFAULT NOW(),
		email TEXT UNIQUE,
		password TEXT,
		"phone no" TEXT,
		address TEXT,
		update_at TIMESTAMPTZ DEFAULT NOW(),
		"first name" TEXT,
		"last name" TEXT,
		profile_photo TEXT
	);`

	// Create ratings table
	ratingsTable := `
	CREATE TABLE IF NOT EXISTS ratings (
		id BIGSERIAL PRIMARY KEY,
		user_id INT8 REFERENCES users(id) ON DELETE CASCADE,
		rating INT4 NOT NULL CHECK (rating >= 1 AND rating <= 5),
		comment TEXT,
		created_at TIMESTAMPTZ DEFAULT NOW()
	);`

	// Create usage table
	usageTable := `
	CREATE TABLE IF NOT EXISTS user_usage (
		id BIGSERIAL PRIMARY KEY,
		user_id INT8 REFERENCES users(id) ON DELETE CASCADE,
		media_type TEXT,
		filename TEXT,
		result TEXT,
		confidence FLOAT8,
		created_at TIMESTAMPTZ DEFAULT NOW()
	);`

	DBPool.Exec(context.Background(), userTable)
	DBPool.Exec(context.Background(), ratingsTable)
	DBPool.Exec(context.Background(), usageTable)
}

func SignupHandler(c echo.Context) error {
	req := new(models.SignupRequest)
	if err := c.Bind(req); err != nil {
		return c.JSON(http.StatusBadRequest, models.AuthResponse{Success: false, Message: "Invalid request"})
	}

	if req.Email == "" || req.Password == "" {
		return c.JSON(http.StatusBadRequest, models.AuthResponse{Success: false, Message: "Email and password are required"})
	}

	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, models.AuthResponse{Success: false, Message: "Error processing password"})
	}

	now := time.Now()

	query := `INSERT INTO users (email, password, "phone no", address, created_at, update_at, "first name", "last name", profile_photo) 
			  VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING id`
	
	var lastID int64
	err = DBPool.QueryRow(context.Background(), query, req.Email, string(hashedPassword), req.PhoneNo, req.Address, now, now, req.FirstName, req.LastName, req.ProfilePhoto).Scan(&lastID)

	if err != nil {
		return c.JSON(http.StatusConflict, models.AuthResponse{Success: false, Message: "User already exists or database error"})
	}

	user := models.User{
		ID:           lastID,
		Email:        req.Email,
		PhoneNo:      req.PhoneNo,
		Address:      req.Address,
		FirstName:    req.FirstName,
		LastName:     req.LastName,
		ProfilePhoto: req.ProfilePhoto,
		CreatedAt:    now,
		UpdatedAt:    now,
	}

	return c.JSON(http.StatusCreated, models.AuthResponse{
		Success: true,
		Message: "User registered successfully",
		User:    &user,
	})
}

func LoginHandler(c echo.Context) error {
	req := new(models.LoginRequest)
	if err := c.Bind(req); err != nil {
		return c.JSON(http.StatusBadRequest, models.AuthResponse{Success: false, Message: "Invalid request"})
	}

	var user models.User
	var hashedPassword string

	query := `SELECT id, email, password, "phone no", address, created_at, update_at, "first name", "last name", COALESCE(profile_photo, '') FROM users WHERE email = $1`
	err := DBPool.QueryRow(context.Background(), query, req.Email).Scan(
		&user.ID, &user.Email, &hashedPassword, &user.PhoneNo, &user.Address, &user.CreatedAt, &user.UpdatedAt, &user.FirstName, &user.LastName, &user.ProfilePhoto,
	)

	if err != nil {
		return c.JSON(http.StatusUnauthorized, models.AuthResponse{Success: false, Message: "Invalid email or password"})
	}

	if err := bcrypt.CompareHashAndPassword([]byte(hashedPassword), []byte(req.Password)); err != nil {
		return c.JSON(http.StatusUnauthorized, models.AuthResponse{Success: false, Message: "Invalid email or password"})
	}

	return c.JSON(http.StatusOK, models.AuthResponse{
		Success: true,
		Message: "Login successful",
		User:    &user,
	})
}

func UpdateUserHandler(c echo.Context) error {
	id := c.Param("id")
	req := new(models.User)
	if err := c.Bind(req); err != nil {
		return c.JSON(http.StatusBadRequest, models.AuthResponse{Success: false, Message: "Invalid request"})
	}

	now := time.Now()
	query := `UPDATE users SET "phone no"=$1, address=$2, update_at=$3, "first name"=$4, "last name"=$5, profile_photo=$6 WHERE id=$7`
	_, err := DBPool.Exec(context.Background(), query, req.PhoneNo, req.Address, now, req.FirstName, req.LastName, req.ProfilePhoto, id)

	if err != nil {
		return c.JSON(http.StatusInternalServerError, models.AuthResponse{Success: false, Message: "Failed to update user"})
	}

	if req.Password != "" {
		hashedPassword, _ := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
		_, _ = DBPool.Exec(context.Background(), "UPDATE users SET password=$1, update_at=$2 WHERE id=$3", string(hashedPassword), now, id)
	}

	return c.JSON(http.StatusOK, models.AuthResponse{
		Success: true,
		Message: "Profile updated successfully",
	})
}

func DeleteUserHandler(c echo.Context) error {
	id := c.Param("id")
	_, err := DBPool.Exec(context.Background(), "DELETE FROM users WHERE id=$1", id)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, models.AuthResponse{Success: false, Message: "Failed to delete user"})
	}

	return c.JSON(http.StatusOK, models.AuthResponse{
		Success: true,
		Message: "Account deleted successfully",
	})
}
