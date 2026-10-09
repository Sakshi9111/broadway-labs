FROM mysql:8.0

ENV MYSQL_ROOT_PASSWORD=rootpass
ENV MYSQL_DATABASE=school
ENV MYSQL_USER=schooluser
ENV MYSQL_PASSWORD=schoolpass

COPY init.sql /docker-entrypoint-initdb.d/init.sql