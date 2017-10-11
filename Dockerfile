# nginx as base so it will share some common base layers with the nginx image
FROM nginx:1.13.1

VOLUME /etc/nginx
COPY /etc/nginx /opt/nginx/

ADD entrypoint /entrypoint
ENTRYPOINT /entrypoint
