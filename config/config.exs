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
config :tailwind,
  version: "4.1.12",
  default: [
    args: ~w(
      --input=css/app.css
      --output=../docs/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]
