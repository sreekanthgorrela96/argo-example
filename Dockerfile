# Keep the latest Nginx Alpine image
FROM docker.io/library/nginx:1.27.4-alpine

# Force an upgrade of system packages to grab the latest security hotfixes
RUN apk update && apk upgrade --no-cache

# Placeholder for secureforge-ui; replace with your app build.
# COPY dist/ /usr/share/nginx/html/
