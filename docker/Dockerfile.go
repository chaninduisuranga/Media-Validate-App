# Build stage
FROM golang:1.25-alpine AS build

WORKDIR /app

# Copy go mod and sum files
COPY backend/go_server/go.mod backend/go_server/go.sum ./
RUN go mod download

# Copy source code
COPY backend/go_server/ .

# Build the application
RUN go build -o main .

# Run stage
FROM alpine:latest

WORKDIR /app

# Copy the binary from the build stage
COPY --from=build /app/main .

# Add non-root user required by WSO2 Choreo
RUN addgroup -S choreouser && adduser -S choreouser -G choreouser -u 10014
RUN chown -R choreouser:choreouser /app
USER 10014

# Expose the API port
EXPOSE 8081

# Command to run the application
CMD ["./main"]
