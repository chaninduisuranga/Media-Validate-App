package models

import "time"

type User struct {
	ID        int64     `json:"id"`
	Email     string    `json:"email"`
	Password  string    `json:"-"` // Hashed password, never return in JSON
	PhoneNo   string    `json:"phone_no"`
	Address   string    `json:"address"`
	FirstName    string    `json:"first_name"`
	LastName     string    `json:"last_name"`
	ProfilePhoto string    `json:"profile_photo"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"update_at"`
}

type SignupRequest struct {
	Email     string `json:"email"`
	Password  string `json:"password"`
	PhoneNo   string `json:"phone_no"`
	Address   string `json:"address"`
	FirstName    string `json:"first_name"`
	LastName     string `json:"last_name"`
	ProfilePhoto string `json:"profile_photo"`
}

type LoginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

type AuthResponse struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
	User    *User  `json:"user,omitempty"`
}
