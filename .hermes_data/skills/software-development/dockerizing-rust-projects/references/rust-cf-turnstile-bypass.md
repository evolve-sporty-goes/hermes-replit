# rust-cf-turnstile-bypass Docker Setup

Concrete example of Dockerizing a multi-binary Rust repo with X11/GUI dependencies.

## Repo Structure

```
rust-cf-turnstile-bypass/
├── Dockerfile
├── Dockerfile.server
├── rust-cf-turnstile-bypass/          # <-- double-nested!
│   ├── token-server/
│   │   ├── Cargo.toml
│   │   └── src/main.rs
│   ├── turnstile-clicker/
│   │   ├── Cargo.toml
│   │   └── src/main.rs
│   └── token-harvester/              # HTML/JS (not Rust)
```

## Key Issues Encountered

### 1. COPY paths wrong (double-nested structure)

The repo is double-nested: `rust-cf-turnstile-bypass/rust-cf-turnstile-bypass/...`

**Fix:** COPY must use the full path from build context:
```dockerfile
COPY rust-cf-turnstile-bypass/token-server/Cargo.toml .
COPY rust-cf-turnstile-bypass/token-server/src ./src
```

### 2. Missing WORKDIR per binary

Original Dockerfile.server had no WORKDIR set before `cargo build`, so cargo ran in `/app` but Cargo.toml was copied to `/app` not `/app/token-server`.

**Fix:**
```dockerfile
WORKDIR /app/token-server
COPY rust-cf-turnstile-bypass/token-server/Cargo.toml .
COPY rust-cf-turnstile-bypass/token-server/src ./src
RUN cargo build --release
```

### 3. Missing system libraries

| Error | Package to add |
|-------|---------------|
| `Package 'xtst' was not found` | `libxtst-dev` |
| `unable to find library -linput` | `libinput-dev` |

**Full working apt line:**
```dockerfile
RUN apt-get update && apt-get install -y \
    libx11-dev libxcb1-dev libxrandr-dev libxinerama-dev \
    libxcursor-dev libxi-dev libxtst-dev libinput-dev \
    libgl1-mesa-dev libssl-dev libudev-dev pkg-config \
    && rm -rf /var/lib/apt/lists/*
```

### 4. Non-existent build target

Original Dockerfile referenced `fetcher/` which doesn't exist in the repo. Removed that section.

## Final Working Dockerfiles

### Dockerfile.server (token server only)
```dockerfile
FROM rust:latest
WORKDIR /app/token-server
COPY rust-cf-turnstile-bypass/token-server/Cargo.toml .
COPY rust-cf-turnstile-bypass/token-server/src ./src
RUN cargo build --release
EXPOSE 8080
CMD ["./target/release/token_server"]
```

### Dockerfile (full: server + clicker)
```dockerfile
FROM rust:latest
RUN apt-get update && apt-get install -y \
    libx11-dev libxcb1-dev libxrandr-dev libxinerama-dev \
    libxcursor-dev libxi-dev libxtst-dev libinput-dev \
    libgl1-mesa-dev libssl-dev libudev-dev pkg-config \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app/token-server
COPY rust-cf-turnstile-bypass/token-server/Cargo.toml .
COPY rust-cf-turnstile-bypass/token-server/src ./src
RUN cargo build --release

WORKDIR /app/turnstile-clicker
COPY rust-cf-turnstile-bypass/turnstile-clicker/Cargo.toml .
COPY rust-cf-turnstile-bypass/turnstile-clicker/src ./src
RUN cargo build --release

WORKDIR /app
CMD ["bash"]
```

## Build & Run

```bash
# Build
docker build -f Dockerfile.server -t rust-cf-turnstile-server:latest .
docker build -f Dockerfile -t rust-cf-turnstile-full:latest .

# Run server
docker run -p 8080:8080 rust-cf-turnstile-server:latest
```
