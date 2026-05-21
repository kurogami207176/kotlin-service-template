FROM gradle:9.5.1-jdk17-alpine AS build
WORKDIR /workspace
COPY . .
RUN ./gradlew --no-daemon installDist

FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
COPY --from=build /workspace/build/install/kotlin-service-template-app/ ./
EXPOSE 8080
ENV PORT=8080
ENTRYPOINT ["./bin/kotlin-service-template-app"]
