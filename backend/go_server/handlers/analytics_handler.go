package handlers

import (
	"context"
	"fmt"
	"net/http"
	"strconv"
	"time"

	"github.com/labstack/echo/v4"
)

type RatingRequest struct {
	UserID  int64  `json:"user_id"`
	Rating  int    `json:"rating"`
	Comment string `json:"comment"`
}

func AddRatingHandler(c echo.Context) error {
	req := new(RatingRequest)
	if err := c.Bind(req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{"success": false, "message": "Invalid request"})
	}

	query := `INSERT INTO ratings (user_id, rating, comment) VALUES ($1, $2, $3)`
	_, err := DBPool.Exec(context.Background(), query, req.UserID, req.Rating, req.Comment)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]interface{}{"success": false, "message": "Failed to save rating"})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{"success": true, "message": "Rating submitted successfully"})
}

func GetAnalyticsHandler(c echo.Context) error {
	userIDStr := c.Param("id")
	userID, _ := strconv.ParseInt(userIDStr, 10, 64)

	var stats struct {
		TotalValidations int `json:"total_validations"`
		PhotoCount       int `json:"photo_count"`
		VideoCount       int `json:"video_count"`
		RealCount        int `json:"real_count"`
		FakeCount        int `json:"fake_count"`
	}

	// Fetch Total
	DBPool.QueryRow(context.Background(), "SELECT COUNT(*) FROM user_usage WHERE user_id = $1", userID).Scan(&stats.TotalValidations)

	// Fetch Media Types
	DBPool.QueryRow(context.Background(), "SELECT COUNT(*) FROM user_usage WHERE user_id = $1 AND media_type = 'photo'", userID).Scan(&stats.PhotoCount)
	DBPool.QueryRow(context.Background(), "SELECT COUNT(*) FROM user_usage WHERE user_id = $1 AND media_type = 'video'", userID).Scan(&stats.VideoCount)

	// Fetch Detection Results
	DBPool.QueryRow(context.Background(), "SELECT COUNT(*) FROM user_usage WHERE user_id = $1 AND result = 'real'", userID).Scan(&stats.RealCount)
	DBPool.QueryRow(context.Background(), "SELECT COUNT(*) FROM user_usage WHERE user_id = $1 AND result IN ('fake', 'edited')", userID).Scan(&stats.FakeCount)

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"stats":   stats,
	})
}

// GetHistoryHandler returns the last 50 scan records for a user, newest first.
func GetHistoryHandler(c echo.Context) error {
	userIDStr := c.Param("id")
	userID, err := strconv.ParseInt(userIDStr, 10, 64)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{"success": false, "message": "Invalid user ID"})
	}

	type HistoryItem struct {
		ID         int64     `json:"id"`
		MediaType  string    `json:"media_type"`
		Filename   string    `json:"filename"`
		Result     string    `json:"result"`
		Confidence float64   `json:"confidence"`
		CreatedAt  time.Time `json:"created_at"`
	}

	rows, err := DBPool.Query(context.Background(),
		`SELECT id, COALESCE(media_type,'photo'), COALESCE(filename,'unknown'), COALESCE(result,'unknown'), COALESCE(confidence,0), COALESCE(created_at, NOW())
		 FROM user_usage
		 WHERE user_id = $1
		 ORDER BY created_at DESC
		 LIMIT 50`,
		userID,
	)
	if err != nil {
		fmt.Printf("History query error: %v\n", err)
		return c.JSON(http.StatusInternalServerError, map[string]interface{}{"success": false, "message": fmt.Sprintf("DB error: %v", err)})
	}
	defer rows.Close()

	history := []HistoryItem{}
	for rows.Next() {
		var item HistoryItem
		err := rows.Scan(&item.ID, &item.MediaType, &item.Filename, &item.Result, &item.Confidence, &item.CreatedAt)
		if err != nil {
			fmt.Printf("SCAN ERROR on history item (ID?): %v\n", err)
			continue
		}
		history = append(history, item)
	}

	fmt.Printf("Successfully fetched %d history items for user %d\n", len(history), userID)
	return c.JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"history": history,
	})
}

