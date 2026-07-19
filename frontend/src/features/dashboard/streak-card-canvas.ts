export interface StreakCardOptions {
  streak: number;
  appName?: string;
  tagline?: string;
  url?: string;
}

export type ShareStreakResult = "shared" | "downloaded" | "cancelled";

const CARD_SIZE = 1080;
const DEFAULT_APP_NAME = "EchoMirror";
const DEFAULT_TAGLINE = "Your mind, reflected back to you.";
const DEFAULT_URL = "echomirrorbutler.vercel.app";

export function drawStreakCard(
  canvas: HTMLCanvasElement,
  options: StreakCardOptions,
): void {
  const {
    streak,
    appName = DEFAULT_APP_NAME,
    tagline = DEFAULT_TAGLINE,
    url = DEFAULT_URL,
  } = options;

  canvas.width = CARD_SIZE;
  canvas.height = CARD_SIZE;

  const ctx = canvas.getContext("2d");
  if (!ctx) {
    throw new Error("Canvas 2D context is not available");
  }

  const background = ctx.createLinearGradient(0, 0, CARD_SIZE, CARD_SIZE);
  background.addColorStop(0, "#0a0f24");
  background.addColorStop(1, "#141d3d");
  ctx.fillStyle = background;
  ctx.fillRect(0, 0, CARD_SIZE, CARD_SIZE);

  ctx.strokeStyle = "rgba(129, 140, 248, 0.35)";
  ctx.lineWidth = 4;
  ctx.strokeRect(48, 48, CARD_SIZE - 96, CARD_SIZE - 96);

  const centerX = CARD_SIZE / 2;
  ctx.textAlign = "center";

  ctx.textBaseline = "middle";
  ctx.fillStyle = "#818cf8";
  ctx.font = "600 60px system-ui, -apple-system, Segoe UI, Roboto, sans-serif";
  ctx.fillText(`✦ ${appName}`, centerX, 190);

  ctx.fillStyle = "#f97316";
  ctx.font = "160px system-ui, -apple-system, Segoe UI, Roboto, sans-serif";
  ctx.fillText("\u{1F525}", centerX, 400);

  ctx.fillStyle = "#ffffff";
  ctx.font = "700 300px system-ui, -apple-system, Segoe UI, Roboto, sans-serif";
  ctx.fillText(String(streak), centerX, 620);

  ctx.fillStyle = "rgba(255, 255, 255, 0.92)";
  ctx.font = "600 66px system-ui, -apple-system, Segoe UI, Roboto, sans-serif";
  ctx.fillText(streak === 1 ? "DAY STREAK" : "DAY STREAK", centerX, 800);

  ctx.fillStyle = "rgba(255, 255, 255, 0.7)";
  ctx.font = "40px system-ui, -apple-system, Segoe UI, Roboto, sans-serif";
  ctx.fillText(tagline, centerX, 900);

  ctx.fillStyle = "rgba(129, 140, 248, 0.85)";
  ctx.font = "600 38px system-ui, -apple-system, Segoe UI, Roboto, sans-serif";
  ctx.fillText(url, centerX, 990);
}

export function createStreakCardBlob(
  options: StreakCardOptions,
): Promise<Blob> {
  const canvas = document.createElement("canvas");
  drawStreakCard(canvas, options);

  return new Promise((resolve, reject) => {
    canvas.toBlob((blob) => {
      if (blob) {
        resolve(blob);
      } else {
        reject(new Error("Could not export streak card image"));
      }
    }, "image/png");
  });
}

function downloadBlob(blob: Blob, filename: string): void {
  const objectUrl = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = objectUrl;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  link.remove();
  URL.revokeObjectURL(objectUrl);
}

export async function shareStreakCard(
  options: StreakCardOptions,
): Promise<ShareStreakResult> {
  const blob = await createStreakCardBlob(options);
  const filename = `echomirror-${options.streak}-day-streak.png`;
  const file = new File([blob], filename, { type: "image/png" });

  const shareData: ShareData = {
    files: [file],
    title: `${options.streak}-day streak on ${options.appName ?? DEFAULT_APP_NAME}`,
    text: `I'm on a ${options.streak}-day mood-logging streak on ${
      options.appName ?? DEFAULT_APP_NAME
    }!`,
  };

  if (
    typeof navigator.share === "function" &&
    typeof navigator.canShare === "function" &&
    navigator.canShare(shareData)
  ) {
    try {
      await navigator.share(shareData);
      return "shared";
    } catch (error) {
      if (error instanceof DOMException && error.name === "AbortError") {
        return "cancelled";
      }
    }
  }

  downloadBlob(blob, filename);
  return "downloaded";
}
