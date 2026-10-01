# nginx-unprivileged runs as non-root on port 8080.
# The official image renders /etc/nginx/templates/*.template with envsubst at startup.
FROM nginxinc/nginx-unprivileged:1.27-alpine
ENV PRODUCT_HOST=product-service:8000 ORDER_HOST=order-service:3000
COPY nginx.conf /etc/nginx/templates/default.conf.template
COPY index.html /usr/share/nginx/html/index.html
EXPOSE 8080
