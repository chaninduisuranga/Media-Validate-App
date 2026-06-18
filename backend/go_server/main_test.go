package main

import "testing"

func TestIsVideoUpload(t *testing.T) {
	tests := []struct {
		name     string
		filename string
		mimeType string
		want     bool
	}{
		{name: "video mime", filename: "upload.bin", mimeType: "video/mp4", want: true},
		{name: "uppercase mp4 extension", filename: "clip.MP4", mimeType: "", want: true},
		{name: "mov extension", filename: "clip.mov", mimeType: "application/octet-stream", want: true},
		{name: "jpeg image", filename: "photo.JPG", mimeType: "image/jpeg", want: false},
		{name: "empty metadata", filename: "upload", mimeType: "", want: false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := isVideoUpload(tt.filename, tt.mimeType); got != tt.want {
				t.Fatalf("isVideoUpload(%q, %q) = %v, want %v", tt.filename, tt.mimeType, got, tt.want)
			}
		})
	}
}
