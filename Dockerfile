# Build stage
FROM rust:1.91-alpine AS builder

# Install build dependencies
RUN apk add --no-cache musl-dev

# Create app directory
WORKDIR /app

# Copy manifests
COPY Cargo.toml Cargo.lock ./

# Build dependencies - this is the caching layer
RUN mkdir src && \
    echo "fn main() {}" > src/main.rs && \
    cargo build --release && \
    rm -rf src

# Copy source code
COPY . .

# Build application
# Touch main.rs to ensure it's newer than the dummy file
RUN touch src/main.rs && \
    cargo build --release

# Runtime stage
FROM alpine:3.22

# Install runtime dependencies
RUN apk add --no-cache \
    ca-certificates \
    && rm -rf /var/cache/apk/*

# Create non-root user
RUN addgroup -g 1001 ferrous && \
    adduser -D -u 1001 -G ferrous ferrous

# Create app directory
WORKDIR /app

# Copy binary from builder
COPY --from=builder /app/target/release/ferrous /app/ferrous

# Ensure binary is executable
RUN chmod +x /app/ferrous

# Change ownership
RUN chown -R ferrous:ferrous /app

# Switch to non-root user
USER ferrous

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health/live || exit 1

# Set default environment variables
ENV RUST_LOG=ferrous=info,tower_http=warn
ENV APP_PROFILE=production

# Run the binary
CMD ["/app/ferrous"]
