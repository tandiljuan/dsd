# Color & Number — Simple Docker static site

A minimal Dockerized static site that serves a full-page number on a colored background. The page template (index.html) is populated at container start using environment variables defined in `config.env` (via `envsubst`) and served with `darkhttpd`.

## Features

- Configurable background color and displayed number via environment variables.
- Uses a lightweight Alpine image with `darkhttpd`.
- Easy to run locally or in a container environment.

## Files

- `index.html` — HTML template using `${BACKGROUND_COLOR}` and `${NUMBER}` placeholders.
- `config.env` — Example environment file. Default sets `BACKGROUND_COLOR="e74c3c"` (red) and `NUMBER=1`.
- `start.sh` — Entrypoint script: loads variables from `config.env` (without overwriting existing environment variables), runs `envsubst` to render `index.html` into `/var/www/index.html`, and starts `darkhttpd`.
- `Dockerfile` — Builds the lightweight container image (Alpine) with `darkhttpd` and `gettext-envsubst`.

## Usage

Prerequisites: Docker installed.

1. Build the image:

   ```
   docker build -t color-number .
   ```

2. Run the container (uses `config.env` defaults):

   ```
   docker run --rm -p 8080:80 color-number
   ```

3. Open [http://localhost:8080](http://localhost:8080) to view the page.

### Override settings

You can override variables at runtime with Docker environment variables. Examples:

Change number:

```
docker run --rm -p 8080:80 -e NUMBER=42 color-number
```

Change background color (hex without `#`):

```
docker run --rm -p 8080:80 -e BACKGROUND_COLOR=2ecc71 color-number
```

Use both:

```
docker run --rm -p 8080:80 -e BACKGROUND_COLOR=3498db -e NUMBER=7 color-number
```

Note: `start.sh` loads `config.env` but will not overwrite environment variables already provided to the container, so Docker `-e` takes precedence.

## Environment file format

`config.env` uses simple KEY="value" lines. Colors should be hex digits (no leading `#`), e.g. `e74c3c` for red.

## Troubleshooting

If the page shows placeholder text (`${NUMBER}` or `${BACKGROUND_COLOR}`) it means `envsubst` did not run or file copy failed, ensure `start.sh` is executable and was used as the container CMD.

To inspect rendered file inside a running container:

```
docker exec -it <container-id> cat /var/www/index.html
```

## Safety note

Before publishing publicly, verify that the HEX color value does not include `#` since the template already inserts `#${BACKGROUND_COLOR}`.

## Development

To test locally without Docker, install `gettext` for `envsubst`, then run:

```
export BACKGROUND_COLOR=e74c3c
export NUMBER=1
envsubst < index.html > /tmp/index.html
python3 -m http.server --directory /tmp 8080
```

The container uses `darkhttpd` to serve files from `/var/www`.
