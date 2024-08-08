# Local Development Setup

We initially started using minikube as the local development environment but we later realised that it adds an extra layer of complexity to our developers. Therefore we resorted to a setup powered by docker-compose. 

Sample directory structure
```
kubeflex-platform
--auth-service
----Dockerfile
--frontend
----Dockerfile
--backend
----Dockerfile
--docker-compose.yaml
```

Sample content of docker-compose.yaml file
```
services:
  frontend:
    build: ./frontend
    ports:
      - "3000:3000"
    environment:
      BACKEND_SERVICE: backend
      BACKEND_SERVICE_PORT: 8080
  backend:
    build: ./backend
    ports:
      - "8080:8080"
    environment:
      SERVICE_PORT: 8080
      MONGODB_URI: mongodb+srv://<user>:<password>@<cluster-name>.xxx.mongodb.net/
  auth-service:
    build: ./auth-service
    ports:
      - "3200:3200"
    environment:
      SERVICE_PORT: 3200
      MYSQL_HOST: mysqldb
      MYSQL_PORT: 3306
      MYSQL_USER: dev-user
      MYSQL_PASSWD: devpassword
  mysqldb:
    image: mysql:8.0.36
    ports:
      - 3306:3306
    restart: unless-stopped
    environment:
      MYSQL_USER: keycloakapp-user
      MYSQL_PASSWORD: keycloak123
      MYSQL_DATABASE: keycloakdb
      MYSQL_ROOT_PASSWORD: devpassword
    volumes:
      - ./mysql_data:/var/lib/mysql
  keycloak:
    image: quay.io/keycloak/keycloak:24.0
    command: start-dev
    ports:
      - 9081:8080
    restart: unless-stopped
    environment:
      KEYCLOAK_ADMIN: admin
      KEYCLOAK_ADMIN_PASSWORD: admin@1234
      KC_DB: mysql
      KC_DB_USERNAME: keycloakapp-user
      KC_DB_PASSWORD: keycloak123
      KC_DB_URL: jdbc:mysql://mysqldb:3306/keycloakdb
      KC_HOSTNAME: localhost
    depends_on:
      - mysqldb
volumes:
  mysql_data:
```

These exact environment variable keys are available in kubernetes in form of secrets (with different values of course)
