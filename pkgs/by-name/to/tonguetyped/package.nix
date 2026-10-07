{
  lib,
  rustPlatform,
  fetchFromGitHub,
  cmake,
  desktop-file-utils,
  libclang,
  makeWrapper,
  pkg-config,
  shaderc,
  alsa-lib,
  onnxruntime,
  spirv-headers,
  xdotool,
  openssl,
  wayland,
  vulkan-headers,
  vulkan-loader,
  libcanberra-gtk3,
  glibc,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "tonguetyped";
  # No tagged release exists upstream yet; pinned to the latest main commit
  # until cheerfulScumbag cuts a release.
  version = "0.1.0-unstable-2026-10-07";

  src = fetchFromGitHub {
    owner = "cheerfulScumbag";
    repo = "tonguetyped";
    rev = "7f7ebb18d36713941753b5ba00aaeeba19c80a48";
    # FIXME: cheerfulScumbag/tonguetyped is currently a private repository,
    # so this source cannot be fetched (by Hydra or anyone else) until it is
    # made public. Replace with the real hash once that happens.
    hash = lib.fakeHash;
  };

  cargoLock = {
    lockFile = ./Cargo.lock;
    outputHashes = {
      "vad-rs-0.1.6" = "sha256-zQr/WVa9SBcPSTrm5DIKYBa3bPuYTQTDEzFkl7cjYTI=";
    };
  };

  postPatch = ''
    ln -sf ${./Cargo.lock} Cargo.lock
  '';

  nativeBuildInputs = [
    cmake
    desktop-file-utils
    libclang
    makeWrapper
    pkg-config
    shaderc
  ];

  buildInputs = [
    alsa-lib
    onnxruntime
    spirv-headers
    xdotool
    openssl
    wayland
    vulkan-headers
    vulkan-loader
  ];

  # Vulkan works across GPU vendors, and InferenceEngine falls back to the
  # CPU backend when Vulkan or its separately installed model is
  # unavailable. CUDA/ROCm remain explicit developer builds outside nixpkgs
  # (CUDA additionally requires allowUnfree, which this package avoids).
  buildFeatures = [ "gpu-vulkan" ];

  env = {
    LIBCLANG_PATH = "${lib.getLib libclang}/lib";
    BINDGEN_EXTRA_CLANG_ARGS = "-I${lib.getDev glibc}/include";
    CMAKE_POLICY_VERSION_MINIMUM = "3.5";
    ORT_LIB_LOCATION = "${onnxruntime}/lib";
    ORT_PREFER_DYNAMIC_LINK = "1";
  };

  # `tests/tui_dashboard.rs`'s `pty_*`-prefixed tests allocate a real
  # pseudo-terminal and spawn the built binary into it (`portable-pty`); the
  # Nix build sandbox's checkPhase has no usable pty/tty subsystem for that
  # nested spawn. They are covered by the project's own CI instead.
  cargoTestFlags = [
    "--"
    "--skip"
    "pty_"
  ];

  postInstall = ''
    install -Dm644 data/tonguetyped.desktop \
      $out/share/applications/io.github.cheerfulScumbag.tonguetyped.desktop
  '';

  postFixup = ''
    wrapProgram $out/bin/tonguetyped \
      --prefix PATH : ${lib.makeBinPath [ libcanberra-gtk3 ]}
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    test -x $out/bin/tonguetyped
    desktop-file-validate $out/share/applications/io.github.cheerfulScumbag.tonguetyped.desktop
    runHook postInstallCheck
  '';

  meta = {
    description = "Local Linux dictation controlled from the terminal or a desktop-wide keyboard shortcut";
    homepage = "https://github.com/cheerfulScumbag/tonguetyped";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ cheerfulScumbag ];
    mainProgram = "tonguetyped";
    platforms = lib.platforms.linux;
  };
})
