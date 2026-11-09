# Build from the repository root: docker build -f services/workshop/Dockerfile .
FROM maven:3.9.11-amazoncorretto-21 AS build
WORKDIR /build
COPY services/workshop/pom.xml ./
COPY services/workshop/src ./src
RUN mvn -B -ntp package -DskipTests && cp target/workshop-0.1.0.jar /app.jar
FROM amazoncorretto:21-al2023-headless
RUN yum install -y shadow-utils curl-minimal && yum clean all && useradd -u 10001 -m app && mkdir -p /data/invoices && chown -R 10001:10001 /data
WORKDIR /app
COPY --from=build --chown=10001:10001 /app.jar /app/app.jar
# RDS CA bundle for sslmode=verify-full (AWS publishes it at this address)
ADD --chmod=644 https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem /app/certs/rds-global-bundle.pem
USER 10001
ENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=70 -XX:+ExitOnOutOfMemoryError"
ENTRYPOINT ["java","-jar","/app/app.jar"]
