import request from "supertest";
import app from "../src/server.js";

describe("DevOps Lab CA Application", () => {
  test("GET / should return the application message", async () => {
    const response = await request(app).get("/");

    expect(response.statusCode).toBe(200);
    expect(response.body.message).toBe(
      "DevOps Lab CA application is running!"
    );
  });

  test("GET /health should return healthy status", async () => {
    const response = await request(app).get("/health");

    expect(response.statusCode).toBe(200);
    expect(response.body.status).toBe("healthy");
  });
});
