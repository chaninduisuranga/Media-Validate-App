package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/joho/godotenv"
	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"
	"github.com/mediavalidate/go_server/handlers"
	"github.com/mediavalidate/go_server/services"
)

var (
	PythonApiUrl = getEnv("PYTHON_API_URL", "http://localhost:8005/predict")
)

func getEnv(key, fallback string) string {
	if value, ok := os.LookupEnv(key); ok {
		return value
	}
	return fallback
}

func main() {
	// Load .env file
	if err := godotenv.Load("../../.env"); err != nil {
		fmt.Println("Warning: No .env file found, using system environment variables")
	}

	// Connect to database
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		fmt.Println("CRITICAL: DATABASE_URL not set")
	} else {
		pool, err := pgxpool.New(context.Background(), dbURL)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Unable to connect to database: %v\n", err)
		} else {
			defer pool.Close()
			handlers.InitDB(pool)
			fmt.Println("Connected to Supabase PostgreSQL successfully")
		}
	}

	// Log Python API URL for debugging
	fmt.Printf("PYTHON_API_URL configured as: %s\n", PythonApiUrl)

	e := echo.New()

	// Middleware
	e.Use(middleware.Logger())
	e.Use(middleware.Recover())
	e.Use(middleware.CORS())

	// Routes
	e.GET("/", func(c echo.Context) error {
		return c.String(http.StatusOK, "Media Validate Go Backend is running")
	})

	e.POST("/api/validate", handleValidation)
	e.POST("/api/signup", handlers.SignupHandler)
	e.POST("/api/login", handlers.LoginHandler)
	e.PUT("/api/user/:id", handlers.UpdateUserHandler)
	e.DELETE("/api/user/:id", handlers.DeleteUserHandler)
	e.POST("/api/rate", handlers.AddRatingHandler)
	e.GET("/api/user/:id/analytics", handlers.GetAnalyticsHandler)
	e.GET("/api/user/:id/history", handlers.GetHistoryHandler)

	// Start server
	port := os.Getenv("PORT")
	if port == "" {
		port = "8081"
	}
	e.Logger.Fatal(e.Start(":" + port))
}

func handleValidation(c echo.Context) error {
	// 1. Read file from request
	file, err := c.FormFile("file")
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "File is required")
	}

	src, err := file.Open()
	if err != nil {
		return err
	}
	defer src.Close()

	fileBytes, err := io.ReadAll(src)
	if err != nil {
		return err
	}
	mimeType := file.Header.Get("Content-Type")

	// 2. Execute Native Go Validation Pipelines
	var goResults []services.ValidationResult
	isEdited := false

	if strings.HasPrefix(mimeType, "video") || strings.HasSuffix(file.Filename, ".mp4") {
		goResults = services.RunVideoValidation(fileBytes, mimeType)
	} else {
		goResults = services.RunImageValidation(fileBytes, mimeType)
	}

	// Iterate to check if our structural checks automatically flag it as FAKE
	for _, res := range goResults {
		if res.Status == "EDITED" {
			isEdited = true
			break
		}
	}

	// Early return structural fake finding
	if isEdited {
		finalResult := map[string]interface{}{
			"filename":     file.Filename,
			"prediction":   "edited",
			"confidence":   99.0,
			"raw_score":    0.0,
			"go_results":   goResults,
			"orchestrator": "Native Go Pipeline",
		}

		// Log usage for early return
		userIDStr := c.FormValue("user_id")
		if userIDStr != "" {
			userID, _ := strconv.ParseInt(userIDStr, 10, 64)
			mediaType := "photo"
			if strings.HasPrefix(mimeType, "video") || strings.HasSuffix(file.Filename, ".mp4") {
				mediaType = "video"
			}
			handlers.DBPool.Exec(context.Background(), 
				"INSERT INTO user_usage (user_id, media_type, filename, result, confidence) VALUES ($1, $2, $3, $4, $5)",
				userID, mediaType, file.Filename, "edited", 99.0)
		}

		return c.JSON(http.StatusOK, finalResult)
	}

	// 3. Fallback to Python Inference deep-learning for Neural Network analysis
	body := &bytes.Buffer{}
	writer := multipart.NewWriter(body)
	part, err := writer.CreateFormFile("file", file.Filename)
	if err != nil {
		return err
	}
	
	if _, err = part.Write(fileBytes); err != nil {
		return err
	}
	writer.Close()

	req, err := http.NewRequest("POST", PythonApiUrl, body)
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", writer.FormDataContentType())

	// Send request to Python
	fmt.Printf("--- Sending validation request to Python API: %s ---\n", PythonApiUrl)
	client := &http.Client{Timeout: 120 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		fmt.Printf("Python API connection error: %v\n", err)
		return echo.NewHTTPError(http.StatusInternalServerError, fmt.Sprintf("AI service error: %v", err))
	}
	defer resp.Body.Close()

	// Parse python response and attach our structural Go findings
	var pythonResponse map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&pythonResponse); err != nil {
		return echo.NewHTTPError(http.StatusInternalServerError, "Failed to parse AI response")
	}
	
	pythonResponse["go_results"] = goResults
	pythonResponse["orchestrator"] = "Go Gateway -> Python AI"

	// 4. Log usage to Database
	userIDStr := c.FormValue("user_id")
	if userIDStr != "" {
		userID, _ := strconv.ParseInt(userIDStr, 10, 64)
		mediaType := "photo"
		if strings.HasPrefix(mimeType, "video") || strings.HasSuffix(file.Filename, ".mp4") {
			mediaType = "video"
		}
		
		pred, ok1 := pythonResponse["prediction"].(string)
		conf, ok2 := pythonResponse["confidence"].(float64)

		if ok1 && ok2 {
			handlers.DBPool.Exec(context.Background(), 
				"INSERT INTO user_usage (user_id, media_type, filename, result, confidence) VALUES ($1, $2, $3, $4, $5)",
				userID, mediaType, file.Filename, pred, conf)
		}
	}

	return c.JSON(resp.StatusCode, pythonResponse)
}

