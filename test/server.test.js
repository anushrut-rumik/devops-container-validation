import request from "supertest";
import app from "../src/server.js";

describe("Temperature Conversion API", () => {
  test("GET / should return the application message", async () => {
    const response = await request(app).get("/");

    expect(response.statusCode).toBe(200);
    expect(response.body.message).toBe(
      "Temperature Conversion API is running!"
    );
    expect(response.body.example).toBe("/convert?celsius=25");
  });

  test("GET /health should return healthy status", async () => {
    const response = await request(app).get("/health");

    expect(response.statusCode).toBe(200);
    expect(response.body.status).toBe("healthy");
  });

  test.each([
    ["25", 77],
    ["0", 32],
    ["100", 212],
    ["-40", -40],
    ["36.5", 97.7],
    ["1e2", 212],
    [" 25 ", 77],
  ])("converts %s Celsius to %s Fahrenheit", async (input, expected) => {
    const response = await request(app).get("/convert").query({ celsius: input });

    expect(response.statusCode).toBe(200);
    expect(response.body.celsius).toBe(Number(input));
    expect(response.body.fahrenheit).toBeCloseTo(expected, 10);
  });

  test.each([
    "/convert",
    "/convert?celsius=",
    "/convert?celsius=%20",
    "/convert?celsius=hello",
    "/convert?celsius=25abc",
    "/convert?celsius=0x19",
    "/convert?celsius=NaN",
    "/convert?celsius=Infinity",
    "/convert?celsius=1e309",
    "/convert?celsius=1e308",
    "/convert?celsius=25&celsius=30",
    "/convert?celsius[]=25",
  ])("rejects invalid input at %s", async (url) => {
    const response = await request(app).get(url);

    expect(response.statusCode).toBe(400);
    expect(response.body.error).toEqual(expect.any(String));
    expect(response.body).not.toHaveProperty("fahrenheit");
  });
});
