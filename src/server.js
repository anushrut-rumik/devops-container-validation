import express from "express";
import { readFileSync } from "node:fs";

const app = express();
const release = JSON.parse(readFileSync(new URL("./release.json", import.meta.url), "utf8"));

app.use(express.json());

app.get("/", (req, res) => {
  res.json({
    message: "DevOps Lab CA application is running!",
    version: "1.0.0",
    release: release.label,
    commit: process.env.APP_COMMIT || "local",
  });
});

app.get("/health", (req, res) => {
  res.status(200).json({
    status: "healthy",
  });
});

const PORT = process.env.PORT || 3000;

if (process.env.NODE_ENV !== "test") {
  app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
  });
}

export default app;
