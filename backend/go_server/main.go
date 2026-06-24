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

func isVideoUpload(filename, mimeType string) bool {
	lowerName := strings.ToLower(filename)
	lowerMime := strings.ToLower(mimeType)
	return strings.HasPrefix(lowerMime, "video/") ||
		strings.HasSuffix(lowerName, ".mp4") ||
		strings.HasSuffix(lowerName, ".mov") ||
		strings.HasSuffix(lowerName, ".avi") ||
		strings.HasSuffix(lowerName, ".mkv")
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

	// --- HF Space Keepalive ---
	// HuggingFace free tier sleeps after ~5min inactivity → causes 60s+ cold start → gateway 504
	// This goroutine pings the HF Space root every 4 minutes to keep it always warm.
	go func() {
		// Derive the base URL from PythonApiUrl (strip /predict)
		baseURL := strings.TrimSuffix(PythonApiUrl, "/predict")
		pingURL := baseURL + "/ready"
		pingClient := &http.Client{Timeout: 10 * time.Second}

		fmt.Printf("Triggering Early-Ping warmup to: %s\n", baseURL)
		// Immediate first ping on startup to wake up HF Space early
		if resp, err := pingClient.Get(pingURL); err == nil {
			resp.Body.Close()
			if resp.StatusCode == http.StatusOK {
				fmt.Printf("[Keepalive] Initial readiness check OK\n")
			} else {
				fmt.Printf("[Keepalive] Initial readiness check returned %d\n", resp.StatusCode)
			}
		} else {
			fmt.Printf("[Keepalive] Initial readiness check failed: %v\n", err)
		}

		ticker := time.NewTicker(4 * time.Minute)
		defer ticker.Stop()
		for range ticker.C {
			resp, err := pingClient.Get(pingURL)
			if err != nil {
				fmt.Printf("[Keepalive] Readiness ping failed: %v\n", err)
			} else {
				resp.Body.Close()
				if resp.StatusCode == http.StatusOK {
					fmt.Printf("[Keepalive] HF Space is ready\n")
				} else {
					fmt.Printf("[Keepalive] HF Space not ready yet (status %d)\n", resp.StatusCode)
				}
			}
		}
	}()

	// Start server
	port := os.Getenv("PORT")
	if port == "" {
		port = "8081"
	}
	e.Logger.Fatal(e.Start(":" + port))
}

func handleValidation(c echo.Context) error {
	// 1. Read file from request
	fmt.Println("--- Received Validate Request ---")
	file, err := c.FormFile("file")
	if err != nil {
		fmt.Printf("Validation failed: form file error: %v\n", err)
		return echo.NewHTTPError(http.StatusBadRequest, "File is required")
	}
	fmt.Printf("Validating file: %s (%d bytes)\n", file.Filename, file.Size)

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

	if isVideoUpload(file.Filename, mimeType) {
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
			if isVideoUpload(file.Filename, mimeType) {
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

	// Send request to Python. Choreo has a hard ~60s gateway timeout, so keep this below it.
	fmt.Printf("--- Sending validation request to Python API: %s ---\n", PythonApiUrl)
	client := &http.Client{Timeout: 50 * time.Second}

	var resp *http.Response
	maxRetries := 1
	for attempt := 1; attempt <= maxRetries; attempt++ {
		if attempt > 1 {
			fmt.Printf("--- Retry attempt %d/%d (Python API cold-start) ---\n", attempt, maxRetries)
			time.Sleep(1 * time.Second) // Minimal delay

			// Rebuild the multipart body for retry
			retryBody := &bytes.Buffer{}
			retryWriter := multipart.NewWriter(retryBody)
			retryPart, _ := retryWriter.CreateFormFile("file", file.Filename)
			retryPart.Write(fileBytes)
			retryWriter.Close()

			req, _ = http.NewRequest("POST", PythonApiUrl, retryBody)
			req.Header.Set("Content-Type", retryWriter.FormDataContentType())
		}

		resp, err = client.Do(req)
		if err == nil && resp.StatusCode != 503 {
			break // Success
		}
		if err != nil {
			fmt.Printf("Python API attempt %d error: %v\n", attempt, err)
		} else if resp.StatusCode == 503 {
			fmt.Printf("Python API attempt %d: models still loading (503)\n", attempt)
			resp.Body.Close()
		}
	}

	if err != nil {
		fmt.Printf("Python API connection failed after %d attempts: %v\n", maxRetries, err)
		// Return 503 with a helpful message so the Flutter app can show a retry prompt
		return echo.NewHTTPError(http.StatusServiceUnavailable, "AI service is warming up. Please wait 30 seconds and try again.")
	}
	defer resp.Body.Close()

	// Parse python response and attach our structural Go findings
	var pythonResponse map[string]interface{}
	bodyBytes, _ := io.ReadAll(resp.Body)

	// Forward non-2xx errors from Python directly to the client
	if resp.StatusCode != http.StatusOK {
		fmt.Printf("Python API returned non-200 status: %d | Body: %s\n", resp.StatusCode, string(bodyBytes))
		// Try to parse Python's error detail for a user-friendly message
		var errBody map[string]interface{}
		if jsonErr := json.Unmarshal(bodyBytes, &errBody); jsonErr == nil {
			if detail, ok := errBody["detail"].(string); ok {
				return echo.NewHTTPError(resp.StatusCode, detail)
			}
		}
		return echo.NewHTTPError(resp.StatusCode, fmt.Sprintf("AI service error (status %d)", resp.StatusCode))
	}

	if err := json.Unmarshal(bodyBytes, &pythonResponse); err != nil {
		fmt.Printf("Failed to parse AI response. Status: %d, Raw Body: %s\n", resp.StatusCode, string(bodyBytes))
		return echo.NewHTTPError(http.StatusInternalServerError, "AI response parse error: check logs")
	}

	pythonResponse["go_results"] = goResults
	pythonResponse["orchestrator"] = "Go Gateway -> Python AI"

	// 4. Log usage to Database
	userIDStr := c.FormValue("user_id")
	if userIDStr != "" {
		userID, _ := strconv.ParseInt(userIDStr, 10, 64)
		mediaType := "photo"
		if isVideoUpload(file.Filename, mimeType) {
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
