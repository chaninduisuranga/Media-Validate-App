# Build stage
FROM golang:1.24-alpine AS build

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

WORKDIR /root/

# Copy the binary from the build stage
COPY --from=build /app/main .

# Expose the API port
EXPOSE 8081

# Command to run the application
CMD ["./main"]
