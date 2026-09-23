(() => {
  "use strict";

  const screen = document.getElementById("screen_container");
  const status = document.getElementById("status");
  const errorBox = document.getElementById("error");
  const resetButton = document.getElementById("reset");
  const fullscreenButton = document.getElementById("fullscreen");
  let emulator;

  function setStatus(message) {
    status.textContent = message;
  }

  function showError(message, error) {
    console.error(message, error || "");
    errorBox.hidden = false;
    errorBox.textContent = `${message}${error ? `: ${error.message || error}` : ""}`;
    setStatus("Emulator failed to start");
  }

  function start() {
    if (typeof V86 !== "function") {
      showError("Failed to load the v86 runtime");
      return;
    }

    try {
      emulator = new V86({
        wasm_path: "./v86/v86.wasm",
        memory_size: 64 * 1024 * 1024,
        vga_memory_size: 2 * 1024 * 1024,
        screen: {
          container: screen,
          encoding: "cp437",
          scaling: 2,
          use_graphical_text: false,
        },
        bios: { url: "./bios/seabios.bin" },
        vga_bios: { url: "./bios/vgabios.bin" },
        fda: { url: "./register.img" },
        boot_order: 0x231,
        autostart: true,
        disable_mouse: true,
      });

      emulator.add_listener("emulator-loaded", () => setStatus("Emulator loaded; booting CashOS..."));
      emulator.add_listener("emulator-started", () => setStatus("CashOS running — click the register for keyboard input"));
      emulator.add_listener("download-error", (event) => showError(`Failed to load ${event.file_name || "an emulator asset"}`));
      screen.addEventListener("click", () => screen.focus());
    } catch (error) {
      showError("Failed to start v86", error);
    }
  }

  resetButton.addEventListener("click", () => {
    if (!emulator) return;
    emulator.restart();
    setStatus("CashOS reset; booting from floppy...");
    screen.focus();
  });

  fullscreenButton.addEventListener("click", () => {
    if (emulator) {
      emulator.screen_go_fullscreen();
    } else if (screen.requestFullscreen) {
      screen.requestFullscreen();
    }
  });

  start();
})();
