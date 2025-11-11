defmodule AnnabelleSite.Blog do
  alias AnnabelleSite.Post

  use NimblePublisher,
    build: Post,
    from: "./posts/**/*.md",
    as: :posts,
    highlighters: [:makeup_elixir, :makeup_erlang]

  @posts Enum.sort_by(@posts, & &1.date, {:desc, Date})

  @tags @posts |> Enum.flat_map(& &1.tags) |> Enum.uniq() |> Enum.sort()

  def all_posts, do: @posts
  def all_tags, do: @tags
end
