#include <WiFi.h>

const char* ssid = "Redmi Note 12";
const char* password = "68986898";
const char* host = "192.168.18.6"; // The IP shown in the app
const int port = 8080;

WiFiClient client;

void setup() {
  Serial.begin(115200);
  WiFi.begin(ssid, password);
  
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  
  Serial.println("\nWiFi connected");
  connectToServer();
}

void connectToServer() {
  while (!client.connected()) {
    Serial.println("Attempting to connect to server...");
    if (client.connect(host, port)) {
      Serial.println("Connected to server");
      // Send initial message
      client.println("ESP32 Connected");
    } else {
      Serial.println("Connection failed. Retrying in 5 seconds...");
      delay(5000);
    }
  }
}

void loop() {
  if (!client.connected()) {
    Serial.println("Connection lost. Reconnecting...");
    connectToServer();
  }
  
  if (client.available()) {
    String data = client.readStringUntil('\n');
    Serial.println("Received: " + data);
  }
  
  // Keep connection alive
  static unsigned long lastPing = 0;
  if (millis() - lastPing > 5000) {
    client.println("ping");
    lastPing = millis();
  }
}