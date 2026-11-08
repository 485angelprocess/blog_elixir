import Config

# Configure esbuild
config :esbuild,
  version: "0.25.0",
  default: [
    args:
      ~w(app.js --bundle --target=es2017 --outdir=../docs/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
# https://discourse.nixos.org/t/cannot-run-tailwind-css-with-elixir-phoenix-1-8-project/69651/5
config :tailwind,
  version: "4.3.0",
  default: [
    args: ~w(
      --input=css/app.css
      --output=../docs/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ],
  path: System.get_env("TAILWINDCSS_PATH")
