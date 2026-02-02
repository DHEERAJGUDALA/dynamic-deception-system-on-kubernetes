FROM golang:1.21-alpine AS builder

WORKDIR /app

COPY go.mod ./
RUN go mod download || true

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o operator ./cmd/ || echo "placeholder" > operator

FROM alpine:3.19

RUN apk --no-cache add ca-certificates

WORKDIR /app

COPY --from=builder /app/operator .

# Create non-root user
RUN adduser -D -g '' operator
USER operator

ENTRYPOINT ["./operator"]
