const express = require("express");
const cors = require("cors");
const axios = require("axios");
const { v4: uuidv4 } = require("uuid");

const app = express();
app.use(cors());
app.use(express.json({ limit: "20mb" }));

// In-memory session store
const sessions = {};

// ========== CONFIG ==========
const OLLAMA_URL = "http://localhost:11434/api/chat";
const MODEL_NAME = "loanshield";

// ========== SYSTEM PROMPT ==========
const SYSTEM_PROMPT = `
You are LoanShield AI — a financial document risk analysis assistant.

You analyze loan agreements, detect hidden charges, identify risky clauses,
and explain them in simple language.

Rules:
- Never invent missing data.
- Only analyze provided content.
- If something is not mentioned, say: "Not explicitly mentioned."
- Be structured and professional.
`;

// ========== CREATE SESSION ==========
app.post("/create-session", (req, res) => {
  const sessionId = uuidv4();

  sessions[sessionId] = [
    {
      role: "system",
      content: SYSTEM_PROMPT,
    },
  ];

  res.json({ sessionId });
});

// ========== CHAT MESSAGE ==========
app.post("/chat", async (req, res) => {
  const { sessionId, message } = req.body;

  if (!sessions[sessionId]) {
    return res.status(400).json({ error: "Invalid session ID" });
  }

  try {
    // Add user message to session memory
    sessions[sessionId].push({
      role: "user",
      content: message,
    });

    const response = await axios.post(OLLAMA_URL, {
      model: MODEL_NAME,
      messages: sessions[sessionId],
      stream: false,
    });

    const assistantReply = response.data.message.content;

    // Save assistant reply
    sessions[sessionId].push({
      role: "assistant",
      content: assistantReply,
    });

    res.json({ reply: assistantReply });

  } catch (error) {
    console.error(error.message);
    res.status(500).json({ error: "Model error" });
  }
});

// ========== DOCUMENT ANALYSIS ==========
app.post("/analyze-document", async (req, res) => {
  const { sessionId, documentText } = req.body;

  if (!sessions[sessionId]) {
    return res.status(400).json({ error: "Invalid session ID" });
  }

  try {
    const analysisPrompt = `
Analyze the following loan agreement:

${documentText}
`;

    sessions[sessionId].push({
      role: "user",
      content: analysisPrompt,
    });

    const response = await axios.post(OLLAMA_URL, {
      model: MODEL_NAME,
      messages: sessions[sessionId],
      stream: false,
    });

    const assistantReply = response.data.message.content;

    sessions[sessionId].push({
      role: "assistant",
      content: assistantReply,
    });

    res.json({ analysis: assistantReply });

  } catch (error) {
    console.error(error.message);
    res.status(500).json({ error: "Analysis failed" });
  }
});

// ========== CLEAR SESSION ==========
app.post("/clear-session", (req, res) => {
  const { sessionId } = req.body;

  if (sessions[sessionId]) {
    delete sessions[sessionId];
  }

  res.json({ message: "Session cleared" });
});

// ========== START SERVER ==========
app.listen(3000, () => {
  console.log("🚀 LoanShield Node server running on port 3000");
});
