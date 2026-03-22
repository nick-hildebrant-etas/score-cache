FROM nginx:1.27-alpine

# Remove the default virtual-host config shipped with the image
RUN rm -f /etc/nginx/conf.d/default.conf

# Copy nginx main configuration
COPY nginx/nginx.conf /etc/nginx/nginx.conf

# Copy virtual-host / proxy rules
COPY nginx/conf.d/ /etc/nginx/conf.d/

# HTTP proxy (80) and gRPC proxy for bazel-remote (9093)
EXPOSE 80
EXPOSE 9093

CMD ["nginx", "-g", "daemon off;"]
