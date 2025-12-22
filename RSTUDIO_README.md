# RStudio Server Docker Setup

This repository contains custom Dockerfiles for building RStudio Server on Ubuntu 22.04.

## Files

- **Dockerfile**: Full version with s6-overlay for process management (similar to rocker/rstudio)
- **Dockerfile.simple**: Simplified version without s6-overlay
- **scripts/rstudio-server.sh**: Service script for s6-overlay

## Build Options

### Option 1: Simple Version (Recommended for most users)
```bash
docker build -f Dockerfile.simple -t my-rstudio:latest .
```

### Option 2: Full Version with s6-overlay
```bash
docker build -t my-rstudio:latest .
```

## Run the Container

```bash
docker run -d \
  --name rstudio \
  -p 8787:8787 \
  -e PASSWORD=yourpassword \
  -v $(pwd)/data:/home/rstudio/data \
  my-rstudio:latest
```

## Access RStudio Server

1. Open your browser and navigate to: `http://localhost:8787`
2. Login with:
   - **Username**: `rstudio`
   - **Default Password**: `rstudio` (or use the PASSWORD env variable)

## Customization

### Change R Version
Edit the `R_VERSION` environment variable in the Dockerfile:
```dockerfile
ENV R_VERSION=4.3.2
```

### Change RStudio Server Version
Edit the `RSTUDIO_VERSION` environment variable:
```dockerfile
ENV RSTUDIO_VERSION=2023.12.1+402
```

Check available versions at: https://posit.co/download/rstudio-server/

### Add Additional R Packages
Modify the R package installation line:
```dockerfile
RUN R -e "install.packages(c('tidyverse', 'devtools', 'rmarkdown', 'shiny', 'your-package'), repos='https://cloud.r-project.org/')"
```

### Add System Dependencies
Add to the apt-get install section:
```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
    your-package \
    another-package \
    && rm -rf /var/lib/apt/lists/*
```

## Environment Variables

- `PASSWORD`: Set custom password for rstudio user (default: rstudio)
- `USER`: Set custom username (default: rstudio)
- `ROOT`: Set to true to give rstudio user sudo privileges

## Volumes

Mount volumes to persist your work:
```bash
-v /path/to/your/projects:/home/rstudio/projects
```

## Key Differences from rocker/rstudio

1. **Built from scratch**: Full control over all components
2. **Ubuntu 22.04 base**: Uses latest LTS Ubuntu instead of Debian
3. **Customizable**: Easy to modify versions and packages
4. **Two variants**: Choose between simple or s6-overlay versions
5. **Transparent**: All installation steps are visible and modifiable

## Troubleshooting

### Container exits immediately
Check logs: `docker logs rstudio`

### Can't login
Ensure the rstudio user was created properly. You can exec into the container:
```bash
docker exec -it rstudio bash
```

### Port already in use
Change the port mapping: `-p 8888:8787`

## Security Notes

- Change the default password in production
- Consider using environment variables for sensitive data
- Don't expose RStudio Server directly to the internet without proper authentication
