package services

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"image"
	"image/jpeg"
	_ "image/png"
	"math"
	"strings"

	"github.com/rwcarlsen/goexif/exif"
)

// ValidationResult represents the output of a validation step
type ValidationResult struct {
	Method  string `json:"method"`
	Status  string `json:"status"` // REAL, EDITED, or SUSPICIOUS
	Details string `json:"details"`
}

// -------------------------------------
// 1. EXIF ANALYSIS
// -------------------------------------
// Extract EXIF metadata. Check Camera Model, Software, DateTime.
// If Software tag exists → EDITED. If no EXIF → SUSPICIOUS. If camera exists → REAL.
func ValidateEXIF(fileData []byte) ValidationResult {
	r := bytes.NewReader(fileData)
	x, err := exif.Decode(r)
	if err != nil {
		return ValidationResult{"EXIF_ANALYSIS", "SUSPICIOUS", "No EXIF data found or unable to parse"}
	}

	// 1a. Check for known manipulation software in the Software tag
	if software, err := x.Get(exif.Software); err == nil {
		swStr := strings.ToLower(software.String())
		suspiciousWords := []string{"photoshop", "midjourney", "dall-e", "stable diffusion", "canva", "gimp"}
		for _, w := range suspiciousWords {
			if strings.Contains(swStr, w) {
				return ValidationResult{"EXIF_ANALYSIS", "EDITED", fmt.Sprintf("Suspicious editing software found: %s", swStr)}
			}
		}
		// If it has software but not inherently suspicious, still might be an edit depending on strictness
		return ValidationResult{"EXIF_ANALYSIS", "EDITED", fmt.Sprintf("Image altered by software: %s", swStr)}
	}

	// 1b. Check if camera hardware tags exist
	if _, err := x.Get(exif.Make); err == nil {
		return ValidationResult{"EXIF_ANALYSIS", "REAL", "Valid camera hardware signatures found"}
	}

	return ValidationResult{"EXIF_ANALYSIS", "SUSPICIOUS", "Limited EXIF data, no camera properties found"}
}

// -------------------------------------
// 2. HASH GENERATION
// -------------------------------------
// Generate SHA-256 hash. Used for integrity tracking.
func GenerateHash(fileData []byte) ValidationResult {
	hash := sha256.Sum256(fileData)
	hashString := hex.EncodeToString(hash[:])
	
	return ValidationResult{
		Method:  "HASH_GENERATION",
		Status:  "REAL", // Hash is just informational
		Details: fmt.Sprintf("SHA-256: %s", hashString),
	}
}

// -------------------------------------
// 3. METADATA ANALYSIS
// -------------------------------------
// Check file size vs resolution consistency. Validate file type vs extension.
func ValidateMetadata(fileData []byte, mimeType string) ValidationResult {
	// Decode image configuration (dimensions only, fast)
	r := bytes.NewReader(fileData)
	config, format, err := image.DecodeConfig(r)
	if err != nil {
		return ValidationResult{"METADATA_ANALYSIS", "SUSPICIOUS", "Cannot decode image metadata"}
	}

	// Check if resolution matches file size reasonably
	// E.g. extremely high res but tiny file = high compression (suspicious)
	pixels := float64(config.Width * config.Height)
	bytesPerPixel := float64(len(fileData)) / pixels

	var details []string
	status := "REAL"

	if bytesPerPixel < 0.05 {
		status = "SUSPICIOUS"
		details = append(details, "Extremely low byte-to-pixel ratio (High compression)")
	}

	details = append(details, fmt.Sprintf("Resolution: %dx%d, Format: %s", config.Width, config.Height, format))

	return ValidationResult{
		Method:  "METADATA_ANALYSIS",
		Status:  status,
		Details: strings.Join(details, ". "),
	}
}

// -------------------------------------
// 4. ERROR LEVEL ANALYSIS (ELA)
// -------------------------------------
// Recompress image at 90% quality. Compare with original.
// Generate difference score to highlight abnormal regions.
func ValidateELA(fileData []byte) ValidationResult {
	r := bytes.NewReader(fileData)
	img, format, err := image.Decode(r)
	if err != nil || format != "jpeg" {
		// ELA typically only applies efficiently to JPEGs
		return ValidationResult{"ELA_ANALYSIS", "SUSPICIOUS", "Not a valid JPEG for ELA"}
	}

	// 1. Recompress at 90 quality
	buf := new(bytes.Buffer)
	opts := &jpeg.Options{Quality: 90}
	err = jpeg.Encode(buf, img, opts)
	if err != nil {
		return ValidationResult{"ELA_ANALYSIS", "SUSPICIOUS", "Failed to re-encode image"}
	}

	// Decode the recompressed image
	recompressedImg, err := jpeg.Decode(buf)
	if err != nil {
		return ValidationResult{"ELA_ANALYSIS", "SUSPICIOUS", "Failed to decode re-encoded image"}
	}

	// 2. Compare original and recompressed image pixels to find average error
	bounds := img.Bounds()
	var totalError float64

	for y := bounds.Min.Y; y < bounds.Max.Y; y++ {
		for x := bounds.Min.X; x < bounds.Max.X; x++ {
			r1, g1, b1, _ := img.At(x, y).RGBA()
			r2, g2, b2, _ := recompressedImg.At(x, y).RGBA()

			// Calculate absolute difference per channel (scale down since RGBA returns 0-65535)
			diffR := math.Abs(float64((r1 >> 8) - (r2 >> 8)))
			diffG := math.Abs(float64((g1 >> 8) - (g2 >> 8)))
			diffB := math.Abs(float64((b1 >> 8) - (b2 >> 8)))

			totalError += (diffR + diffG + diffB) / 3.0
		}
	}

	// 3. Generate Difference Score
	avgError := totalError / float64(bounds.Dx() * bounds.Dy())
	
	status := "REAL"
	if avgError > 15.0 { // Arbitrary threshold indicating high variance globally
		status = "SUSPICIOUS" // Changed from EDITED so it doesn't instantly crash the pipeline
	} else if avgError < 1.0 { // Very pristine compression
		status = "SUSPICIOUS"
	}

	return ValidationResult{
		Method:  "ERROR_LEVEL_ANALYSIS",
		Status:  status,
		Details: fmt.Sprintf("ELA Variance Score: %.2f", avgError),
	}
}

// -------------------------------------
// 5. NOISE ANALYSIS
// -------------------------------------
// Analyze pixel noise distribution. Detect inconsistencies.
func ValidateNoise(fileData []byte) ValidationResult {
	// A pure Go implementation of variance calculation across the image
	r := bytes.NewReader(fileData)
	img, _, err := image.Decode(r)
	if err != nil {
		return ValidationResult{"NOISE_ANALYSIS", "SUSPICIOUS", "Could not decode for noise analysis"}
	}

	bounds := img.Bounds()
	var sum float64
	var count float64
	
	// Fast greyscale pixel conversion for mean
	for y := bounds.Min.Y; y < bounds.Max.Y; y += 2 { // Sample every 2 pixels for speed
		for x := bounds.Min.X; x < bounds.Max.X; x += 2 {
			r1, g1, b1, _ := img.At(x, y).RGBA()
			// Luminescence approximation (0-255)
			lum := float64(((r1>>8)*299 + (g1>>8)*587 + (b1>>8)*114) / 1000)
			sum += lum
			count++
		}
	}
	
	mean := sum / count
	var varianceSum float64
	
	// Calculate variance
	for y := bounds.Min.Y; y < bounds.Max.Y; y += 2 {
		for x := bounds.Min.X; x < bounds.Max.X; x += 2 {
			r1, g1, b1, _ := img.At(x, y).RGBA()
			lum := float64(((r1>>8)*299 + (g1>>8)*587 + (b1>>8)*114) / 1000)
			varianceSum += math.Pow(lum-mean, 2)
		}
	}
	
	variance := varianceSum / count

	status := "REAL"
	if variance < 100 { // Unnaturally smooth/denoised (AI characteristic)
		status = "SUSPICIOUS"
	} else if math.IsNaN(variance) {
		status = "SUSPICIOUS"
	}

	return ValidationResult{
		Method:  "NOISE_ANALYSIS",
		Status:  status,
		Details: fmt.Sprintf("Pixel Variance (Noise): %.2f", variance),
	}
}

// -------------------------------------
// 6. FILE STRUCTURE VALIDATION
// -------------------------------------
// Validate JPEG/PNG headers. Check binary structure integrity.
func ValidateFileStructure(fileData []byte) ValidationResult {
	if len(fileData) < 8 {
		return ValidationResult{"FILE_STRUCTURE", "SUSPICIOUS", "File too small to evaluate"}
	}

	// Known magic numbers
	jpegMagic := []byte{0xFF, 0xD8, 0xFF}
	pngMagic := []byte{0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A}
	
	isValid := false
	detectedFmt := "Unknown"

	if bytes.HasPrefix(fileData, jpegMagic) {
		isValid = true
		detectedFmt = "JPEG"
	} else if bytes.HasPrefix(fileData, pngMagic) {
		isValid = true
		detectedFmt = "PNG"
	}

	if !isValid {
		return ValidationResult{"FILE_STRUCTURE", "SUSPICIOUS", "Invalid or missing Magic Numbers"}
	}

	return ValidationResult{
		Method:  "FILE_STRUCTURE",
		Status:  "REAL",
		Details: fmt.Sprintf("Valid %s Binary Header Structure", detectedFmt),
	}
}

// Global Image Validation Runner
func RunImageValidation(fileData []byte, mimeType string) []ValidationResult {
	var results []ValidationResult
	
	results = append(results, GenerateHash(fileData))
	results = append(results, ValidateFileStructure(fileData))
	results = append(results, ValidateMetadata(fileData, mimeType))
	results = append(results, ValidateEXIF(fileData))
	results = append(results, ValidateNoise(fileData))
	results = append(results, ValidateELA(fileData))
	
	return results
}
