 # Start from golang base image
FROM golang:1.17-alpine as builder

# Set the current working directory inside the container
WORKDIR /usr/src/app

# Copy go.mod, go.sum files and download deps
COPY go.* ./
RUN go mod download

# Copy sources to the working directory
COPY . .

# Build the app
RUN GOOS=linux CGO_ENABLED=0 GOARCH=amd64 go build -a -v -o hero-app ./main.go

# Start from the busybox image and copy the executable
FROM alpine:3.15

COPY --from=builder /usr/src/app/hero-app /usr/bin/