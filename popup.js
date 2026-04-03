const symbolOptions = [
  { label: "-", description: "ハイフン", value: "-" },
  { label: "_", description: "アンダーバー", value: "_" },
  { label: "@", description: "アット", value: "@" },
  { label: "/", description: "スラッシュ", value: "/" },
  { label: "*", description: "アスタリスク", value: "*" },
  { label: "+", description: "プラス", value: "+" },
  { label: ".", description: "ドット", value: "." },
  { label: ",", description: "カンマ", value: "," },
  { label: "!", description: "エクスクラメーション", value: "!" },
  { label: "?", description: "クエスチョン", value: "?" },
  { label: "#", description: "シャープ", value: "#" },
  { label: "$", description: "ドル", value: "$" },
  { label: "%", description: "パーセント", value: "%" },
  { label: "&", description: "アンド", value: "&" },
  { label: "(", description: "左かっこ", value: "(" },
  { label: ")", description: "右かっこ", value: ")" },
  { label: "{", description: "左波かっこ", value: "{" },
  { label: "}", description: "右波かっこ", value: "}" },
  { label: "[", description: "左角かっこ", value: "[" },
  { label: "]", description: "右角かっこ", value: "]" },
  { label: "~", description: "チルダ", value: "~" },
  { label: "|", description: "パイプ", value: "|" },
  { label: ":", description: "コロン", value: ":" },
  { label: ";", description: "セミコロン", value: ";" },
  { label: "\"", description: "ダブルクォート", value: "\"" },
  { label: "'", description: "シングルクォート", value: "'" },
  { label: "^", description: "キャレット", value: "^" },
  { label: ">", description: "大なり", value: ">" },
  { label: "<", description: "小なり", value: "<" },
  { label: "=", description: "イコール", value: "=" }
];

const defaultSettings = {
  uppercase: true,
  lowercase: true,
  digits: true,
  includeSymbols: true,
  selectAllSymbols: false,
  symbols: symbolOptions.map(() => true),
  length: 16,
  count: 6,
  excludeSimilar: true,
  noConsecutive: false,
  theme: "blue"
};

const similarCharacters = new Set(["I", "l", "1", "O", "0", "o"]);
const storageArea = globalThis.browser?.storage?.local || globalThis.chrome?.storage?.local || null;
const minPasswordLength = 4;
const maxPasswordLength = 999999;
const minPasswordCount = 1;
const maxPasswordCount = 30;
let generationSequence = 0;

document.addEventListener("DOMContentLoaded", async () => {
  const elements = getElements();
  renderSymbolOptions(elements.symbolsCheckboxes, elements.selectAllSymbols);
  wireEvents(elements);
  await loadSettings(elements);
  toggleSymbolsPanel(elements);
  normalizeNumericInputs(elements);
  updateProgress(elements, 0, 0);
  elements.emptyState.hidden = false;
  switchTab(elements, "settings");
});

function getElements() {
  return {
    tabSettings: document.getElementById("tab-settings"),
    tabResults: document.getElementById("tab-results"),
    viewSettings: document.getElementById("view-settings"),
    viewResults: document.getElementById("view-results"),
    uppercase: document.getElementById("uppercase"),
    lowercase: document.getElementById("lowercase"),
    digits: document.getElementById("digits"),
    includeSymbols: document.getElementById("include-symbols"),
    selectAllSymbols: document.getElementById("select-all-symbols"),
    symbolsPanel: document.getElementById("symbols-panel"),
    symbolsCheckboxes: document.getElementById("symbols-checkboxes"),
    symbolImportInput: document.getElementById("symbol-import-input"),
    symbolImportApply: document.getElementById("symbol-import-apply"),
    themeButtons: Array.from(document.querySelectorAll(".theme-swatch")),
    length: document.getElementById("length"),
    lengthError: document.getElementById("length-error"),
    count: document.getElementById("count"),
    countError: document.getElementById("count-error"),
    excludeSimilar: document.getElementById("exclude-similar"),
    noConsecutive: document.getElementById("no-consecutive"),
    generate: document.getElementById("generate"),
    settingsStatus: document.getElementById("settings-status"),
    statusMessage: document.getElementById("status-message"),
    progressIndicator: document.getElementById("progress-indicator"),
    emptyState: document.getElementById("empty-state"),
    passwordList: document.getElementById("password-list"),
    passwordItemTemplate: document.getElementById("password-item-template")
  };
}

function renderSymbolOptions(container, selectAllElement) {
  const fragment = document.createDocumentFragment();

  symbolOptions.forEach((symbol, index) => {
    const label = document.createElement("label");
    label.className = "symbol-chip";
    label.title = symbol.description;

    const checkbox = document.createElement("input");
    checkbox.type = "checkbox";
    checkbox.value = symbol.value;
    checkbox.dataset.index = String(index);
    checkbox.checked = defaultSettings.symbols[index];
    checkbox.addEventListener("change", () => {
      syncSelectAllState(container, selectAllElement);
      void persistSettings(getElements());
    });

    const span = document.createElement("span");
    span.className = "symbol-glyph";
    span.textContent = symbol.label;

    label.append(checkbox, span);
    fragment.appendChild(label);
  });

  container.appendChild(fragment);
}

function wireEvents(elements) {
  elements.tabSettings.addEventListener("click", () => {
    switchTab(elements, "settings");
  });

  elements.tabResults.addEventListener("click", () => {
    switchTab(elements, "results");
  });

  const optionInputs = [
    elements.uppercase,
    elements.lowercase,
    elements.digits,
    elements.includeSymbols,
    elements.excludeSimilar,
    elements.noConsecutive
  ];

  optionInputs.forEach((element) => {
    element.addEventListener("change", async () => {
      toggleSymbolsPanel(elements);
      syncSelectAllState(elements.symbolsCheckboxes, elements.selectAllSymbols);
      renderStatus(elements.settingsStatus, "", "info");
      await persistSettings(elements);
    });
  });

  elements.themeButtons.forEach((button) => {
    button.addEventListener("click", async () => {
      const theme = button.dataset.theme ?? defaultSettings.theme;
      applyTheme(theme);
      syncThemeButtons(elements.themeButtons, theme);
      await persistSettings(elements);
    });
  });

  const numericInputs = [elements.length, elements.count];

  numericInputs.forEach((element) => {
    element.addEventListener("input", () => {
      clearFieldErrors(elements);
      renderStatus(elements.settingsStatus, "", "info");
    });

    element.addEventListener("blur", async () => {
      normalizeNumericInputs(elements, { source: element });
      await persistSettings(elements);
    });
  });

  elements.selectAllSymbols.addEventListener("change", async () => {
    const symbolCheckboxes = getSymbolCheckboxes(elements.symbolsCheckboxes);
    symbolCheckboxes.forEach((checkbox) => {
      checkbox.checked = elements.selectAllSymbols.checked;
    });
    await persistSettings(elements);
  });

  elements.symbolImportInput.addEventListener("input", () => {
    elements.symbolImportApply.disabled = elements.symbolImportInput.value.length === 0;
  });

  elements.symbolImportApply.addEventListener("click", async () => {
    applyImportedSymbols(elements);
    await persistSettings(elements);
  });

  elements.generate.addEventListener("click", () => {
    void generateAndRenderPasswords(elements, { revealResults: true });
  });
}

function switchTab(elements, tabName) {
  const showResults = tabName === "results";
  elements.tabSettings.classList.toggle("is-active", !showResults);
  elements.tabResults.classList.toggle("is-active", showResults);
  elements.viewSettings.hidden = showResults;
  elements.viewResults.hidden = !showResults;
}

function toggleSymbolsPanel(elements) {
  elements.symbolsPanel.hidden = !elements.includeSymbols.checked;
}

function syncSelectAllState(container, selectAllElement) {
  const symbolCheckboxes = getSymbolCheckboxes(container);
  const checkedCount = symbolCheckboxes.filter((checkbox) => checkbox.checked).length;
  selectAllElement.checked = checkedCount > 0 && checkedCount === symbolCheckboxes.length;
}

function getSymbolCheckboxes(container) {
  return Array.from(container.querySelectorAll('input[type="checkbox"]'));
}

function getSettingsControls(elements) {
  return [
    elements.uppercase,
    elements.lowercase,
    elements.digits,
    elements.includeSymbols,
    elements.selectAllSymbols,
    ...getSymbolCheckboxes(elements.symbolsCheckboxes),
    elements.symbolImportInput,
    elements.symbolImportApply,
    ...elements.themeButtons,
    elements.length,
    elements.count,
    elements.excludeSimilar,
    elements.noConsecutive
  ];
}

function setGeneratingState(elements, isGenerating) {
  getSettingsControls(elements).forEach((element) => {
    element.disabled = isGenerating;
  });

  elements.symbolImportApply.disabled = isGenerating || elements.symbolImportInput.value.length === 0;
  elements.generate.disabled = isGenerating;
  elements.generate.classList.toggle("is-generating", isGenerating);
  elements.generate.textContent = isGenerating ? "生成中..." : "生成";
}

function applyImportedSymbols(elements) {
  const importedValue = elements.symbolImportInput.value;
  if (!importedValue) {
    elements.symbolImportApply.disabled = true;
    return false;
  }

  const importedCharacters = new Set(importedValue.split(""));
  const hasSupportedSymbol = symbolOptions.some((symbol) => importedCharacters.has(symbol.value));
  if (!hasSupportedSymbol) {
    elements.symbolImportInput.value = "";
    elements.symbolImportApply.disabled = true;
    return false;
  }

  const symbolCheckboxes = getSymbolCheckboxes(elements.symbolsCheckboxes);
  symbolCheckboxes.forEach((checkbox) => {
    checkbox.checked = importedCharacters.has(checkbox.value);
  });

  syncSelectAllState(elements.symbolsCheckboxes, elements.selectAllSymbols);
  elements.symbolImportInput.value = "";
  elements.symbolImportApply.disabled = true;
  return true;
}

function getMaxCountForLength(length) {
  const normalizedLength = clampNumber(length, minPasswordLength, maxPasswordLength);
  return Math.max(minPasswordCount, Math.min(maxPasswordCount, Math.floor(maxPasswordLength / normalizedLength)));
}

function clampNumber(value, minimum, maximum) {
  return Math.min(maximum, Math.max(minimum, value));
}

function normalizeNumericInputs(elements, options = {}) {
  const { source = null } = options;
  const rawLength = sanitizeNumber(elements.length.value, defaultSettings.length);
  const normalizedLength = clampNumber(rawLength, minPasswordLength, maxPasswordLength);
  const maxCountForLength = getMaxCountForLength(normalizedLength);
  const rawCount = sanitizeNumber(elements.count.value, defaultSettings.count);
  const normalizedCount = clampNumber(rawCount, minPasswordCount, maxCountForLength);
  const lengthAdjusted = rawLength !== normalizedLength;
  const countAdjusted = rawCount !== normalizedCount;

  clearFieldErrors(elements);
  elements.length.value = String(normalizedLength);
  elements.count.max = String(maxCountForLength);
  elements.count.value = String(normalizedCount);

  if (source === elements.length && lengthAdjusted) {
    setFieldError(elements.length, elements.lengthError, `${minPasswordLength}〜${maxPasswordLength.toLocaleString()}に補正しました。`);
  }

  if (source === elements.count && countAdjusted) {
    setFieldError(elements.count, elements.countError, `1〜${maxCountForLength}に補正しました。`);
    return;
  }

  if (source === elements.count && rawCount > maxCountForLength) {
    setFieldError(elements.count, elements.countError, `この文字数では最大 ${maxCountForLength} 件です。`);
    return;
  }

  if (source === elements.length && maxCountForLength < rawCount) {
    setFieldError(elements.count, elements.countError, `件数を ${maxCountForLength} 件に調整しました。`);
  }
}

function clearFieldErrors(elements) {
  elements.lengthError.textContent = "";
  elements.countError.textContent = "";
  elements.length.closest(".stat")?.removeAttribute("data-invalid");
  elements.count.closest(".stat")?.removeAttribute("data-invalid");
}

function setFieldError(inputElement, errorElement, message) {
  errorElement.textContent = message;
  inputElement.closest(".stat")?.setAttribute("data-invalid", "true");
}

async function loadSettings(elements) {
  const settings = {
    ...defaultSettings,
    ...(await readSettings())
  };

  elements.uppercase.checked = settings.uppercase;
  elements.lowercase.checked = settings.lowercase;
  elements.digits.checked = settings.digits;
  elements.includeSymbols.checked = settings.includeSymbols;
  elements.length.value = String(settings.length);
  elements.count.value = String(settings.count);
  elements.excludeSimilar.checked = settings.excludeSimilar;
  elements.noConsecutive.checked = settings.noConsecutive;
  const theme = settings.theme ?? defaultSettings.theme;

  const symbolCheckboxes = getSymbolCheckboxes(elements.symbolsCheckboxes);
  symbolCheckboxes.forEach((checkbox, index) => {
    checkbox.checked = settings.symbols[index] ?? defaultSettings.symbols[index];
  });

  syncSelectAllState(elements.symbolsCheckboxes, elements.selectAllSymbols);
  normalizeNumericInputs(elements);
  applyTheme(theme);
  syncThemeButtons(elements.themeButtons, theme);
}

async function persistSettings(elements) {
  const settings = collectSettings(elements);
  await writeSettings(settings);
}

function collectSettings(elements) {
  return {
    uppercase: elements.uppercase.checked,
    lowercase: elements.lowercase.checked,
    digits: elements.digits.checked,
    includeSymbols: elements.includeSymbols.checked,
    selectAllSymbols: elements.selectAllSymbols.checked,
    symbols: getSymbolCheckboxes(elements.symbolsCheckboxes).map((checkbox) => checkbox.checked),
    length: clampNumber(sanitizeNumber(elements.length.value, defaultSettings.length), minPasswordLength, maxPasswordLength),
    count: clampNumber(
      sanitizeNumber(elements.count.value, defaultSettings.count),
      minPasswordCount,
      getMaxCountForLength(sanitizeNumber(elements.length.value, defaultSettings.length))
    ),
    excludeSimilar: elements.excludeSimilar.checked,
    noConsecutive: elements.noConsecutive.checked,
    theme: document.body.dataset.theme || defaultSettings.theme
  };
}

function sanitizeNumber(value, fallback) {
  const numericValue = Number.parseInt(value, 10);
  return Number.isFinite(numericValue) ? numericValue : fallback;
}

async function readSettings() {
  if (!storageArea) {
    return null;
  }

  if (typeof storageArea.get === "function") {
    try {
      if (storageArea.get.length <= 1) {
        const result = await storageArea.get("passgenSettings");
        return result.passgenSettings ?? null;
      }

      return await new Promise((resolve) => {
        storageArea.get("passgenSettings", (result) => {
          resolve(result.passgenSettings ?? null);
        });
      });
    } catch (error) {
      console.error("設定の読み込みに失敗しました。", error);
    }
  }

  return null;
}

async function writeSettings(settings) {
  if (!storageArea || typeof storageArea.set !== "function") {
    return;
  }

  try {
    if (storageArea.set.length <= 1) {
      await storageArea.set({ passgenSettings: settings });
      return;
    }

    await new Promise((resolve) => {
      storageArea.set({ passgenSettings: settings }, resolve);
    });
  } catch (error) {
    console.error("設定の保存に失敗しました。", error);
  }
}

async function generateAndRenderPasswords(elements, options = {}) {
  const { revealResults = false } = options;
  const currentGeneration = ++generationSequence;
  normalizeNumericInputs(elements);
  const settings = collectSettings(elements);
  const validationError = validateSettings(settings, elements);

  if (validationError) {
    renderStatus(elements.settingsStatus, validationError, "error");
    renderStatus(elements.statusMessage, "", "info");
    elements.passwordList.innerHTML = "";
    elements.emptyState.hidden = false;
    updateProgress(elements, 0, 0);
    switchTab(elements, "settings");
    return;
  }

  clearFieldErrors(elements);
  renderStatus(elements.settingsStatus, "", "info");
  renderStatus(elements.statusMessage, "", "info");
  elements.passwordList.innerHTML = "";
  elements.emptyState.hidden = true;
  updateProgress(elements, 0, settings.count);
  setGeneratingState(elements, true);
  await yieldToUi();

  if (revealResults) {
    switchTab(elements, "results");
  }

  try {
    for (let index = 0; index < settings.count; index += 1) {
      if (currentGeneration !== generationSequence) {
        return;
      }

      const password = await createPassword(settings, elements);
      appendPassword(password, elements, index);
      updateProgress(elements, index + 1, settings.count);

      if (index < settings.count - 1) {
        await yieldToUi();
      }
    }

    if (currentGeneration !== generationSequence) {
      return;
    }

    void writeSettings(settings);
  } finally {
    if (currentGeneration === generationSequence) {
      setGeneratingState(elements, false);
    }
  }
}

function validateSettings(settings, elements) {
  clearFieldErrors(elements);

  if (!settings.uppercase && !settings.lowercase && !settings.digits && !settings.includeSymbols) {
    return "少なくとも 1 つの文字セットを選択してください。";
  }

  if (settings.length < minPasswordLength || settings.length > maxPasswordLength) {
    setFieldError(elements.length, elements.lengthError, "4〜999,999で入力してください。");
    elements.length.focus();
    return "文字数を見直してください。";
  }

  const maxCountForLength = getMaxCountForLength(settings.length);
  elements.count.max = String(maxCountForLength);

  if (settings.count < minPasswordCount || settings.count > maxCountForLength) {
    setFieldError(elements.count, elements.countError, `1〜${maxCountForLength}で入力してください。`);
    elements.count.focus();
    return "生成件数を見直してください。";
  }

  const pools = buildPools(settings, elements);
  if (pools.length === 0) {
    return "選択した条件で使える文字がありません。設定を見直してください。";
  }

  if (settings.length < pools.length) {
    setFieldError(elements.length, elements.lengthError, `少なくとも ${pools.length} 文字必要です。`);
    elements.length.focus();
    return "文字数が短すぎます。";
  }

  const combined = combinePools(pools);
  if (settings.noConsecutive && combined.length < 2 && settings.length > 1) {
    return "同じ文字を連続させない設定では、少なくとも 2 種類以上の文字が必要です。";
  }

  return null;
}

function buildPools(settings, elements) {
  const pools = [];

  if (settings.uppercase) {
    const chars = normalizeCharacters("ABCDEFGHIJKLMNOPQRSTUVWXYZ", settings.excludeSimilar);
    if (chars) {
      pools.push({ id: "uppercase", label: "大文字", characters: chars });
    }
  }

  if (settings.lowercase) {
    const chars = normalizeCharacters("abcdefghijklmnopqrstuvwxyz", settings.excludeSimilar);
    if (chars) {
      pools.push({ id: "lowercase", label: "小文字", characters: chars });
    }
  }

  if (settings.digits) {
    const chars = normalizeCharacters("0123456789", settings.excludeSimilar);
    if (chars) {
      pools.push({ id: "digits", label: "数字", characters: chars });
    }
  }

  if (settings.includeSymbols) {
    const selectedSymbols = getSymbolCheckboxes(elements.symbolsCheckboxes)
      .filter((checkbox) => checkbox.checked)
      .map((checkbox) => checkbox.value)
      .join("");
    const chars = normalizeCharacters(selectedSymbols, false);

    if (chars) {
      pools.push({ id: "symbols", label: "記号", characters: chars });
    }
  }

  return pools;
}

function normalizeCharacters(characters, excludeSimilar) {
  const filtered = Array.from(new Set(characters.split(""))).filter((character) => {
    if (!excludeSimilar) {
      return true;
    }
    return !similarCharacters.has(character);
  });

  return filtered.join("");
}

function combinePools(pools) {
  return Array.from(new Set(pools.flatMap((pool) => pool.characters.split("")))).join("");
}

function createPassword(settings, elements) {
  const pools = buildPools(settings, elements);
  const requiredPoolIds = new Set(pools.map((pool) => pool.id));
  const passwordCharacters = [];
  let previousChar = "";
  let iterationsSinceYield = 0;

  while (passwordCharacters.length < settings.length) {
    const remainingSlots = settings.length - passwordCharacters.length;
    const availablePools = selectCandidatePools(pools, requiredPoolIds, remainingSlots, settings.noConsecutive, previousChar);

    if (availablePools.length === 0) {
      throw new Error("条件に合うパスワードを生成できませんでした。");
    }

    const selectedPool = availablePools[randomInt(availablePools.length)];
    const character = pickCharacter(selectedPool.characters, previousChar, settings.noConsecutive);

    if (!character) {
      throw new Error("利用可能な文字が不足しています。");
    }

    passwordCharacters.push(character);
    previousChar = character;
    requiredPoolIds.delete(selectedPool.id);
    iterationsSinceYield += 1;

    if (iterationsSinceYield >= 2048) {
      iterationsSinceYield = 0;
      return yieldToUi().then(() => createPasswordContinuation(
        settings,
        pools,
        requiredPoolIds,
        passwordCharacters,
        previousChar
      ));
    }
  }

  return {
    value: passwordCharacters.join(""),
    entropy: estimateEntropy(combinePools(pools).length, settings.length)
  };
}

function createPasswordContinuation(settings, pools, requiredPoolIds, passwordCharacters, previousChar) {
  let currentPreviousChar = previousChar;
  let iterationsSinceYield = 0;

  while (passwordCharacters.length < settings.length) {
    const remainingSlots = settings.length - passwordCharacters.length;
    const availablePools = selectCandidatePools(pools, requiredPoolIds, remainingSlots, settings.noConsecutive, currentPreviousChar);

    if (availablePools.length === 0) {
      throw new Error("条件に合うパスワードを生成できませんでした。");
    }

    const selectedPool = availablePools[randomInt(availablePools.length)];
    const character = pickCharacter(selectedPool.characters, currentPreviousChar, settings.noConsecutive);

    if (!character) {
      throw new Error("利用可能な文字が不足しています。");
    }

    passwordCharacters.push(character);
    currentPreviousChar = character;
    requiredPoolIds.delete(selectedPool.id);
    iterationsSinceYield += 1;

    if (iterationsSinceYield >= 2048) {
      iterationsSinceYield = 0;
      return yieldToUi().then(() => createPasswordContinuation(
        settings,
        pools,
        requiredPoolIds,
        passwordCharacters,
        currentPreviousChar
      ));
    }
  }

  return {
    value: passwordCharacters.join(""),
    entropy: estimateEntropy(combinePools(pools).length, settings.length)
  };
}

function selectCandidatePools(pools, requiredPoolIds, remainingSlots, noConsecutive, previousChar) {
  const requiredPools = pools.filter((pool) => requiredPoolIds.has(pool.id));
  const sourcePools = remainingSlots === requiredPools.length
    ? requiredPools
    : requiredPools.length > 0 && randomInt(100) < 55
      ? requiredPools
      : pools;

  const validPools = sourcePools.filter((pool) => hasAvailableCharacter(pool.characters, previousChar, noConsecutive));

  if (validPools.length > 0) {
    return validPools;
  }

  return pools.filter((pool) => hasAvailableCharacter(pool.characters, previousChar, noConsecutive));
}

function hasAvailableCharacter(characters, previousChar, noConsecutive) {
  if (!noConsecutive) {
    return characters.length > 0;
  }

  return characters.split("").some((character) => character !== previousChar);
}

function pickCharacter(characters, previousChar, noConsecutive) {
  const candidates = noConsecutive
    ? characters.split("").filter((character) => character !== previousChar)
    : characters.split("");

  if (candidates.length === 0) {
    return null;
  }

  return candidates[randomInt(candidates.length)];
}

function randomInt(max) {
  if (!Number.isInteger(max) || max <= 0) {
    throw new Error("max must be a positive integer");
  }

  const limit = Math.floor(0x100000000 / max) * max;
  const buffer = new Uint32Array(1);

  while (true) {
    crypto.getRandomValues(buffer);
    if (buffer[0] < limit) {
      return buffer[0] % max;
    }
  }
}

function estimateEntropy(charsetSize, length) {
  return Math.round(length * Math.log2(charsetSize) * 10) / 10;
}

function appendPassword(password, elements, index) {
  const item = elements.passwordItemTemplate.content.firstElementChild.cloneNode(true);
  const passwordValue = item.querySelector(".password-value");
  const passwordNote = item.querySelector(".password-note");
  const strengthBadge = item.querySelector(".strength-badge");
  const entropyText = item.querySelector(".entropy-text");
  const copyStatus = item.querySelector(".copy-status");
  const copyButton = item.querySelector(".copy-button");

  passwordValue.textContent = getDisplayPassword(password.value);
  const note = getPasswordNote(password.value);
  passwordNote.textContent = note;
  passwordNote.hidden = note === "";

  const strength = getStrengthLabel(password.entropy);
  strengthBadge.textContent = strength;
  entropyText.textContent = `推定 ${formatNumber(password.entropy)} bits`;

  copyButton.addEventListener("click", async () => {
    await copyToClipboard(password.value);
    showCopyStatus(copyStatus);
  });

  item.classList.add("enter");
  item.style.animationDelay = `${index * 24}ms`;
  elements.passwordList.appendChild(item);
}

function updateProgress(elements, completed, total) {
  elements.progressIndicator.textContent = `(${completed}/${total})`;
}

function showCopyStatus(element) {
  if (element._hideTimer) {
    clearTimeout(element._hideTimer);
  }

  element.hidden = false;
  element._hideTimer = setTimeout(() => {
    element.hidden = true;
    element._hideTimer = null;
  }, 1800);
}

function getDisplayPassword(password) {
  const maxVisibleLength = 100;
  if (password.length <= maxVisibleLength) {
    return password;
  }

  return `${password.slice(0, maxVisibleLength)}...`;
}

function getPasswordNote(password) {
  const maxVisibleLength = 100;
  if (password.length <= maxVisibleLength) {
    return "";
  }

  return `表示は先頭 ${formatNumber(maxVisibleLength)} 文字までです。実際の文字数は ${formatNumber(password.length)} 文字です。`;
}

function applyTheme(themeName) {
  document.body.dataset.theme = themeName || defaultSettings.theme;
}

function syncThemeButtons(buttons, activeTheme) {
  buttons.forEach((button) => {
    const isActive = button.dataset.theme === activeTheme;
    button.classList.toggle("is-active", isActive);
    button.setAttribute("aria-pressed", String(isActive));
  });
}

function yieldToUi() {
  return new Promise((resolve) => {
    requestAnimationFrame(() => {
      setTimeout(resolve, 0);
    });
  });
}

function formatNumber(value) {
  return new Intl.NumberFormat("ja-JP", {
    maximumFractionDigits: 1,
    minimumFractionDigits: Number.isInteger(value) ? 0 : 1
  }).format(value);
}

function getStrengthLabel(entropy) {
  if (entropy >= 100) {
    return "Very Strong";
  }
  if (entropy >= 80) {
    return "Strong";
  }
  if (entropy >= 60) {
    return "Good";
  }
  return "Basic";
}

function renderStatus(element, message, tone) {
  element.textContent = message;
  element.dataset.tone = tone;
}

async function copyToClipboard(text) {
  if (navigator.clipboard?.writeText) {
    await navigator.clipboard.writeText(text);
    return;
  }

  const input = document.createElement("textarea");
  input.value = text;
  input.style.position = "fixed";
  input.style.opacity = "0";
  document.body.appendChild(input);
  input.focus();
  input.select();
  document.execCommand("copy");
  input.remove();
}
