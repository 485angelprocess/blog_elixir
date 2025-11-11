defmodule AnnabelleSite do
    use Phoenix.Component
    import Phoenix.HTML

    def post(assigns) do
      ~H"""
      <.layout>
        <a href="/../index.html">home</a>
        <%= raw @post.body %>
      </.layout>
      """
    end

    def index(assigns) do
      ~H"""
      <.layout>
        <h1 class="text-3xl font-bold">Annabelle Adelaide</h1>
        <p>Embedded, hardware and FPGA engineer</p>
        <ul class="text-2x1">
          <li class="p-4 b-sky"
           :for={post <- @posts}>
            <span>
              <time><%= post.date %></time>
            </span>
            <a href={post.path}> <%= post.title %> </a>
            <%= Enum.join(post.tags, ", ") %>
          </li>
        </ul>
      </.layout>
      """
    end

    def layout(assigns) do
      ~H"""
      <html>
      <head>
        <link href="https://unpkg.com/tailwindcss@2.2.19/dist/tailwind.min.css" rel="stylesheet">
        <link rel="stylesheet" href="/assets/app.css"/>
        <script type="text/javascript" src="/assets/app.js"/>
        <meta charset="UTF-8">
      </head>
        <body>
          <div class="bg-linear-65 from-purple-500 to-pink-500">
          <%= render_slot(@inner_block) %>
          </div>
        </body>
      </html>
      """
    end

  
  @output_dir "./docs"
  File.mkdir_p!(@output_dir)

  def build() do
    posts = AnnabelleSite.Blog.all_posts()

    render_file("index.html", index(%{posts: posts}))

    for post <- posts do
      dir = Path.dirname(post.path)
      if dir != "." do
        File.mkdir_p!(Path.join([@output_dir, dir]))
      end
      render_file(post.path, post(%{post: post}))
    end

    :ok
  end

  def render_file(path, rendered) do
    safe = Phoenix.HTML.Safe.to_iodata(rendered)
    output = Path.join([@output_dir, path])
    File.write!(output, safe)
  end
end
