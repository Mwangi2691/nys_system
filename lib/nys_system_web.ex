defmodule NysSystemWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, components, channels, and so on.

  This can be used in your application as:

      use NysSystemWeb, :controller
      use NysSystemWeb, :html

  The definitions below will be executed for every controller,
  component, etc, so keep them short and clean, focused
  on imports, uses, and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define additional modules and import
  those modules here.
  """

  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)

  # =====================
  # Router helpers
  # =====================
  def router do
    quote do
      use Phoenix.Router, helpers: false
      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  # =====================
  # Controllers
  # =====================
  def controller do
    quote do
      use Phoenix.Controller, formats: [:html, :json]
      use Gettext, backend: NysSystemWeb.Gettext

      import Plug.Conn
      unquote(verified_routes())
    end
  end

  # =====================
  # Views
  # =====================
  def view do
    quote do
      use Phoenix.View,
        root: "lib/nys_system_web/templates",
        namespace: NysSystemWeb

      # Controller helpers
      import Phoenix.Controller,
        only: [get_flash: 1, get_flash: 2, view_module: 1, view_template: 1]

      import NysSystemWeb.ErrorHelpers
      import NysSystemWeb.Gettext
      alias NysSystemWeb.Router.Helpers, as: Routes
    end
  end

  # =====================
  # LiveView / LiveComponent
  # =====================
  def live_view do
    quote do
      use Phoenix.LiveView
      unquote(html_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent
      unquote(html_helpers())
    end
  end

  # =====================
  # HTML components
  # =====================
def html do
  quote do
    use Phoenix.Component

    # Core helpers
    import Phoenix.HTML
    import Phoenix.HTML.Form
    import Phoenix.LiveView.Helpers

    # Application helpers
    import NysSystemWeb.CoreComponents
    import NysSystemWeb.Gettext

    # Routes with ~p via VerifiedRoutes
    unquote(verified_routes())
  end
end



  defp html_helpers do
    quote do
      # Translation
      import NysSystemWeb.Gettext

      # Core UI components
      import NysSystemWeb.CoreComponents

      # HTML escaping / helpers
      import Phoenix.HTML

      # Routes with ~p
      unquote(verified_routes())
    end
  end

  # =====================
  # Verified routes
  # =====================
  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: NysSystemWeb.Endpoint,
        router: NysSystemWeb.Router,
        statics: NysSystemWeb.static_paths()
    end
  end

  # =====================
  # Channels
  # =====================
  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  # =====================
  # Macro dispatch
  # =====================
  @doc """
  When used, dispatch to the appropriate controller, live_view, etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
