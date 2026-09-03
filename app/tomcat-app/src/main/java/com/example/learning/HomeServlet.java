package com.example.learning;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.secretsmanager.SecretsManagerClient;
import software.amazon.awssdk.services.secretsmanager.model.GetSecretValueRequest;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.Statement;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;

/**
 * The learning page is served from src/main/webapp/index.html. This servlet
 * exposes only the same-origin JSON API required by the runtime status panel.
 */
@WebServlet(urlPatterns = "/api/status")
public class HomeServlet extends HttpServlet {
    private static final ObjectMapper JSON = new ObjectMapper();

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws IOException {
        response.setContentType("application/json; charset=UTF-8");
        response.setHeader("Cache-Control", "no-store");

        List<Message> messages = new ArrayList<>();
        String dbStatus = "Not checked";
        boolean dbConnected = false;

        try {
            JsonNode secret = loadSecret();
            String url = "jdbc:mysql://" + secret.get("host").asText() + ":" + secret.get("port").asInt()
                    + "/" + secret.get("dbname").asText()
                    + "?useSSL=true&requireSSL=false&serverTimezone=UTC";
            Class.forName("com.mysql.cj.jdbc.Driver");
            try (Connection connection = DriverManager.getConnection(
                    url,
                    secret.get("username").asText(),
                    secret.get("password").asText());
                 Statement statement = connection.createStatement();
                 ResultSet rows = statement.executeQuery(
                         "SELECT title, body, created_at FROM messages ORDER BY id")) {
                while (rows.next()) {
                    messages.add(new Message(rows.getString(1), rows.getString(2), rows.getString(3)));
                }
                dbStatus = "Connected to Amazon RDS MySQL";
                dbConnected = true;
                logEvent("INFO Database connection succeeded; rows=" + messages.size());
            }
        } catch (Exception e) {
            dbStatus = "Connection failed: " + e.getClass().getSimpleName();
            getServletContext().log("Database connection failed", e);
            logEvent("ERROR Database connection failed: " + e.getClass().getSimpleName());
        }

        Metadata metadata = metadata();
        StatusResponse payload = new StatusResponse(
                dbStatus,
                dbConnected,
                OffsetDateTime.now().toString(),
                maskInstanceId(metadata.instanceId),
                metadata.availabilityZone,
                System.getProperty("app.version", "unknown"),
                messages);
        JSON.writeValue(response.getWriter(), payload);
    }

    private JsonNode loadSecret() throws IOException {
        String arn = System.getProperty("db.secret.arn", System.getenv("DB_SECRET_ARN"));
        if (arn == null || arn.isBlank()) {
            throw new IllegalStateException("db.secret.arn is not configured");
        }
        Region region = Region.of(System.getProperty(
                "aws.region",
                System.getenv().getOrDefault("AWS_REGION", "ap-northeast-1")));
        try (SecretsManagerClient client = SecretsManagerClient.builder().region(region).build()) {
            String value = client.getSecretValue(
                    GetSecretValueRequest.builder().secretId(arn).build()).secretString();
            return JSON.readTree(value);
        }
    }

    private Metadata metadata() {
        try {
            HttpClient client = HttpClient.newBuilder()
                    .connectTimeout(java.time.Duration.ofSeconds(1))
                    .build();
            HttpRequest tokenRequest = HttpRequest.newBuilder(
                            URI.create("http://169.254.169.254/latest/api/token"))
                    .header("X-aws-ec2-metadata-token-ttl-seconds", "60")
                    .PUT(HttpRequest.BodyPublishers.noBody())
                    .build();
            String token = client.send(tokenRequest, HttpResponse.BodyHandlers.ofString()).body();
            String document = client.send(
                    HttpRequest.newBuilder(
                                    URI.create("http://169.254.169.254/latest/dynamic/instance-identity/document"))
                            .header("X-aws-ec2-metadata-token", token)
                            .GET()
                            .build(),
                    HttpResponse.BodyHandlers.ofString()).body();
            JsonNode node = JSON.readTree(document);
            return new Metadata(
                    node.path("instanceId").asText("unknown"),
                    node.path("availabilityZone").asText("unknown"));
        } catch (Exception ignored) {
            return new Metadata("unavailable", "unavailable");
        }
    }

    private void logEvent(String message) {
        try {
            Files.writeString(
                    Path.of("/var/log/aws-learning-web/app.log"),
                    OffsetDateTime.now() + " " + message + System.lineSeparator(),
                    StandardOpenOption.CREATE,
                    StandardOpenOption.APPEND);
        } catch (IOException ignored) {
            getServletContext().log("Unable to write application log");
        }
    }

    private String maskInstanceId(String instanceId) {
        if (instanceId == null || !instanceId.startsWith("i-") || instanceId.length() < 8) {
            return instanceId == null ? "unavailable" : instanceId;
        }
        return "i-************" + instanceId.substring(instanceId.length() - 4);
    }

    private record Message(String title, String body, String createdAt) {}

    private record Metadata(String instanceId, String availabilityZone) {}

    private record StatusResponse(
            String dbStatus,
            boolean dbConnected,
            String currentTime,
            String instanceId,
            String availabilityZone,
            String appVersion,
            List<Message> messages) {}
}
