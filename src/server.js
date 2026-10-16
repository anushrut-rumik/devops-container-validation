import express from "express";

const app = express();

app.use(express.json());

app.get("/", (req, res) => {
  res.json({
    message: "Temperature Conversion API is running!",
    version: "1.0.0",
    example: "/convert?celsius=25",
  });
});

app.get("/health", (req, res) => {
  res.status(200).json({
    status: "healthy",
  });
});

app.get("/convert", (req, res) => {
  const input = req.query.celsius;

  // Accept one decimal number, including negative values and scientific notation.
  const decimalPattern = /^[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:e[+-]?\d+)?$/i;
  if (typeof input !== "string" || !decimalPattern.test(input.trim())) {
    return res.status(400).json({
      error: "Provide one numeric celsius value, for example /convert?celsius=25.",
    });
  }

  const celsius = Number(input);
  const fahrenheit = celsius * 1.8 + 32;

  if (!Number.isFinite(celsius) || !Number.isFinite(fahrenheit)) {
    return res.status(400).json({
      error: "The celsius value is outside the supported numeric range.",
    });
  }

  return res.json({ celsius, fahrenheit });
});

const PORT = process.env.PORT || 3000;

if (process.env.NODE_ENV !== "test") {
  app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
  });
}

export default app;
