(() => {
  "use strict";

  const quizCards = [...document.querySelectorAll(".quiz-card")];
  const answers = new Map();
  const totalElement = document.getElementById("score-total");
  const correctElement = document.getElementById("score-correct");
  const answeredElement = document.getElementById("score-answered");

  totalElement.textContent = String(quizCards.length);

  function updateScore() {
    const values = [...answers.values()];
    correctElement.textContent = String(values.filter(Boolean).length);
    answeredElement.textContent = String(values.length);
  }

  function answerQuestion(card, button) {
    const isCorrect = card.dataset.kind === "boolean"
      ? button.dataset.choice === card.dataset.correct
      : button.dataset.correct === "true";

    card.querySelectorAll("button[data-choice]").forEach((item) => {
      item.classList.toggle("selected", item === button);
      item.setAttribute("aria-pressed", item === button ? "true" : "false");
    });
    card.classList.toggle("correct", isCorrect);
    card.classList.toggle("incorrect", !isCorrect);

    const feedback = card.querySelector(".quiz-feedback");
    const explanation = card.querySelector(".quiz-explanation");
    feedback.textContent = isCorrect ? "正解です" : "不正解です";
    feedback.hidden = false;
    explanation.hidden = false;
    answers.set(card, isCorrect);
    updateScore();
  }

  quizCards.forEach((card) => {
    card.querySelectorAll("button[data-choice]").forEach((button) => {
      button.setAttribute("aria-pressed", "false");
      button.addEventListener("click", () => answerQuestion(card, button));
    });
  });

  document.getElementById("reset-quiz").addEventListener("click", () => {
    answers.clear();
    quizCards.forEach((card) => {
      card.classList.remove("correct", "incorrect");
      card.querySelectorAll("button[data-choice]").forEach((button) => {
        button.classList.remove("selected");
        button.setAttribute("aria-pressed", "false");
      });
      card.querySelector(".quiz-feedback").hidden = true;
      card.querySelector(".quiz-explanation").hidden = true;
    });
    updateScore();
  });

  const chapterSelect = document.getElementById("chapter-select");
  chapterSelect.addEventListener("change", () => {
    document.querySelector(chapterSelect.value)?.scrollIntoView({ behavior: "smooth" });
  });

  const navigationLinks = [...document.querySelectorAll(".sidebar nav a")];
  const observedSections = navigationLinks
    .map((link) => document.querySelector(link.getAttribute("href")))
    .filter(Boolean);

  const observer = new IntersectionObserver((entries) => {
    const visible = entries
      .filter((entry) => entry.isIntersecting)
      .sort((a, b) => b.intersectionRatio - a.intersectionRatio)[0];
    if (!visible) return;
    const target = `#${visible.target.id}`;
    navigationLinks.forEach((link) => link.classList.toggle("active", link.getAttribute("href") === target));
    if ([...chapterSelect.options].some((option) => option.value === target)) {
      chapterSelect.value = target;
    }
  }, { rootMargin: "-15% 0px -65%", threshold: [0, .2, .5] });
  observedSections.forEach((section) => observer.observe(section));

  const progressBar = document.getElementById("reading-progress-bar");
  function updateReadingProgress() {
    const scrollable = document.documentElement.scrollHeight - window.innerHeight;
    const progress = scrollable > 0 ? (window.scrollY / scrollable) * 100 : 0;
    progressBar.style.width = `${Math.min(100, Math.max(0, progress))}%`;
  }
  window.addEventListener("scroll", updateReadingProgress, { passive: true });
  updateReadingProgress();

  function setText(id, value, fallback = "取得できません") {
    document.getElementById(id).textContent = value || fallback;
  }

  function renderMessages(messages) {
    const container = document.getElementById("db-messages");
    container.replaceChildren();
    if (!Array.isArray(messages) || messages.length === 0) {
      const empty = document.createElement("p");
      empty.className = "muted";
      empty.textContent = "表示する行がありません。seed_db.pyの実行状態を確認してください。";
      container.append(empty);
      return;
    }
    messages.forEach((message) => {
      const article = document.createElement("article");
      const title = document.createElement("h4");
      const body = document.createElement("p");
      const time = document.createElement("time");
      title.textContent = message.title || "Untitled";
      body.textContent = message.body || "";
      time.textContent = message.createdAt || "";
      article.append(title, body, time);
      container.append(article);
    });
  }

  async function loadRuntimeStatus() {
    const header = document.getElementById("header-runtime-status");
    const dot = document.querySelector(".status-dot");
    const dbCard = document.getElementById("db-status-card");
    try {
      const response = await fetch("/api/status", { headers: { Accept: "application/json" }, cache: "no-store" });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const data = await response.json();
      setText("db-status", data.dbStatus);
      setText("instance-id", data.instanceId);
      setText("availability-zone", data.availabilityZone);
      setText("app-version", data.appVersion);
      setText("runtime-time", `API response: ${data.currentTime || "unknown"}`);
      dbCard.classList.toggle("ok", Boolean(data.dbConnected));
      dbCard.classList.toggle("warn", !data.dbConnected);
      header.textContent = data.dbConnected ? "Web / DB 接続中" : "Web稼働中・DB要確認";
      dot.classList.add("online");
      renderMessages(data.messages);
    } catch (error) {
      header.textContent = "静的教材モード";
      dot.classList.add("offline");
      setText("db-status", "APIに接続できません");
      setText("instance-id", "static preview");
      setText("availability-zone", "not available");
      setText("app-version", "not available");
      setText("runtime-time", "教材本文と問題はそのまま利用できます。");
      dbCard.classList.add("warn");
      renderMessages([]);
    }
  }

  loadRuntimeStatus();
})();
