# Multi-stage build to minimize the memory footprint during compilation
FROM maven:3.9.6-eclipse-temurin-17-alpine AS builder
WORKDIR /build
COPY pom.xml .
COPY src ./src
RUN mvn clean package -DskipTests

FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
COPY --from=builder /build/target/*.jar app.jar

# Explicitly limit internal application heap memory inside Kubernetes
ENV JAVA_TOOL_OPTIONS="-Xms128m -Xmx256m"
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
