---
name: dockerizing-rust-projects
description: "Build and debug Docker images for Rust projects with system-library dependencies (X11, Wayland, audio, input). Covers fixing linker errors, missing .pc files, multi-binary repos, and COPY path pitfalls."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos]
metadata:
  hermes:
    tags: [docker, rust, containers, linking, x11, system-libraries, build-fixes]
    related_skills: [systematic-debugging, workspace-organization]
---

# Dockerizing Rust Projects

Build correct Docker images for Rust projects that depend on system libraries — GUI toolkits (X11/Wayland), input handling (libinput, libxtst), audio, graphics (OpenGL/Mesa), and other native crates.

**Core principle:** Rust crates that bind to C system libraries need those dev packages installed in the Docker image *before* `cargo build`. When the build fails with `error: linking with 'cc' failed` or `unable to find library -l<name>`, the fix is almost always adding a `apt-get install -y lib<name>-dev` line.

## When to Use

- User asks to "dockerize", "containerize", "build a Docker image for" a Rust project
- `cargo build` inside Docker fails with linker errors (`-lX`, `-lY not found`)
- pkg-config can't find `.pc` files during build
- Dockerfile COPY paths don't match the actual repo layout
- Multi-binary repos (workspace or sibling crates) need correct WORKDIR per build

## The Process

### Phase 1 — Inspect the repo structure

Before writing a Dockerfile, map the repo:

```bash
# Find all Cargo.toml files (each is a binary/crate)
find . -name "Cargo.toml" -not -path "*/target/*" -not -path "*/.git/*"

# Check if it's a workspace (root Cargo.toml has [workspace])
cat Cargo.toml | head -20

# Read each binary's Cargo.toml to identify dependencies
```

Key things to catch:
- **Nested structure**: Repo root may not be the crate root. `repo/Cargo.toml` might be a workspace, with actual binaries in `repo/crates/*/Cargo.toml` or `repo/subdir/Cargo.toml`.
- **Multi-binary**: Multiple independent binaries need separate `WORKDIR` + `cargo build` steps.

### Phase 2 — Identify required system libraries

Read each `Cargo.toml` and map crates to system deps:

| Crate | Required apt packages |
|-------|----------------------|
| `x11` | `libx11-dev`, `libxtst-dev` |
| `inputbot`, `enigo` | `libinput-dev`, `libx11-dev`, `libxcb1-dev`, `libxtst-dev` |
| `screenshots` | `libx11-dev`, `libxcb1-dev`, `libgl1-mesa-dev`, `libwayland-dev` |
| `alsa-sys` | `libasound2-dev` |
| `pulseaudio` | `libpulse-dev` |
| `openssl` | `libssl-dev`, `pkg-config` |
| `sqlite` | `libsqlite3-dev` |
| `gtk`, `tao` | `libgtk-3-dev`, `libwebkit2gtk-4.0-dev` |
| `sdl2` | `libsdl2-dev` |
| `minifb`, `winit` | `libx11-dev`, `libxcb1-dev`, `libxi-dev`, `libgl1-mesa-dev` |
| `wayland-client` | `libwayland-dev`, `wayland-protocols` |
| `udev` | `libudev-dev` |
| `dbus` | `libdbus-1-dev` |

**General X11 GUI baseline** (covers most GUI crates):
```dockerfile
RUN apt-get update && apt-get install -y \
    libx11-dev libxcb1-dev libxrandr-dev libxinerama-dev \
    libxcursor-dev libxi-dev libxtst-dev libinput-dev \
    libgl1-mesa-dev libssl-dev libudev-dev libdbus-1-dev \
    pkg-config && rm -rf /var/lib/apt/lists/*
```

### Phase 3 — Write the Dockerfile

**Pattern for single binary:**
```dockerfile
FROM rust:latest
RUN apt-get update && apt-get install -y <system-deps> && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY Cargo.toml Cargo.lock ./
COPY src ./src
RUN cargo build --release
CMD ["./target/release/<binary-name>"]
```

**Pattern for multi-binary / non-standard layout:**
```dockerfile
FROM rust:latest
RUN apt-get update && apt-get install -y <system-deps> && rm -rf /var/lib/apt/lists/*

# Build binary 1
WORKDIR /app/bin1
COPY <actual-path>/Cargo.toml .
COPY <actual-path>/src ./src
RUN cargo build --release

# Build binary 2
WORKDIR /app/bin2
COPY <actual-path>/Cargo.toml .
COPY <actual-path>/src ./src
RUN cargo build --release

WORKDIR /app
CMD ["bash"]
```

**Critical: COPY paths are relative to the build context (repo root), NOT the Dockerfile location.** If the repo has a nested structure like `repo/rust-cf-turnstile-bypass/token-server/`, the COPY must include the full path from repo root:
```dockerfile
# WRONG (assumes files are at repo root)
COPY token-server/Cargo.toml .

# RIGHT (matches actual nested layout)
COPY rust-cf-turnstile-bypass/token-server/Cargo.toml .
```

### Phase 4 — Build and iterate on errors

```bash
docker build -f Dockerfile -t <image-name> .
```

Common errors and fixes:

| Error | Fix |
|-------|-----|
| `unable to find library -l<input>` | Add `libinput-dev` |
| `Package xtst was not found` | Add `libxtst-dev` |
| `Package xcb was not found` | Add `libxcb1-dev` |
| `cannot find -lX11` | Add `libx11-dev` |
| `cannot find -ludev` | Add `libudev-dev` |
| `cannot find -ldbus-1` | Add `libdbus-1-dev` |
| `failed to run custom build command for x11` | Usually missing `libxtst-dev` or `pkg-config` |
| `fatal error: 'X11/Xlib.h' file not found` | Add `libx11-dev` |
| `fatal error: 'GL/gl.h' file not found` | Add `libgl1-mesa-dev` or `libgl-dev` |
| `openssl/hmac.h not found` | Add `libssl-dev pkg-config` |
| `wayland-client.h not found` | Add `libwayland-dev` |

**Iteration strategy:** Add the missing package, rebuild. Each linker error names the missing lib (`-l<input>` → `libinput-dev`). Don't try to guess all deps upfront — build, read the error, fix, repeat.

### Phase 5 — Verify

```bash
# Check image built
docker images | grep <image-name>

# Run and check binary exists
docker run --rm <image-name> ls -la /app/target/release/

# For servers: start and check logs
docker run --rm -p <port>:<port> --name test <image-name>
docker logs test
docker rm test
```

## Pitfalls

- **COPY path mismatch.** The #1 issue with Rust Dockerfiles. The build context is the directory you pass to `docker build` (usually `.`). All COPY paths are relative to that context. If your repo has `src/token-server/Cargo.toml` but your Dockerfile says `COPY token-server/Cargo.toml .`, it fails. Always verify with `find . -name Cargo.toml`.
- **Referenced build target doesn't exist.** Original Dockerfiles may reference directories that don't exist in the repo (e.g., `COPY fetcher/Cargo.toml .` when there's no `fetcher/`). Always cross-reference the actual repo structure with `find . -type f -not -path '*/target/*' -not -path '*/.git/*'` before trusting a Dockerfile.
- **Missing WORKDIR per binary.** When building multiple binaries in one image, each needs its own `WORKDIR` before `cargo build`, otherwise the second build overwrites the first or fails because Cargo.toml isn't where cargo expects it.
- **Not cleaning apt cache.** Always `rm -rf /var/lib/apt/lists/*` after `apt-get install` to keep image size down.
- **Using `rust:latest` vs pinned version.** `rust:latest` is fine for dev but pin to a specific tag (e.g., `rust:1.79-bookworm`) for reproducible builds.
- **Forgetting `pkg-config`.** Many `-sys` crates need `pkg-config` to locate system libraries. Always include it.
- **Assuming all deps are listed in Cargo.toml.** `[build-dependencies]` and `[dev-dependencies]` may also need system libs. Check the full manifest.
- **Not checking for `[workspace]`.** If the root Cargo.toml defines a workspace, individual crates may have their own system deps not visible at the root level.

## Related

- Use `systematic-debugging` for build failures that aren't simple missing-library errors.
- Use `workspace-organization` when the repo structure is unclear and needs mapping before Dockerizing.
