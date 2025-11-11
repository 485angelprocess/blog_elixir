watchers: [  
# Start the esbuild watcher by calling Esbuild.install_and_run(:default, args)  
  esbuild: {Esbuild, :install_and_run, [:myproject, ~w(--sourcemap=inline --watch)]},  
  tailwind: {Tailwind, :install_and_run, [:myproject, ~w(--watch)]}
]
