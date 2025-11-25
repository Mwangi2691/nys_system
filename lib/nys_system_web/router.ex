defmodule NysSystemWeb.Router do
  use NysSystemWeb, :router

  # ============================================
  # PIPELINES
  # ============================================

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :put_root_layout, html: {NysSystemWeb.Layouts, :root}
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_session
  end

  pipeline :require_auth do
    plug :check_authenticated
  end

  pipeline :require_admin do
    plug :check_admin
  end

  pipeline :require_commander do
    plug :require_commander_role
  end

  pipeline :require_oc do
    plug :require_oc_role
  end

  # NEW: Pipeline for automatic role-based routing
  pipeline :role_redirect do
    plug NysSystemWeb.Plugs.RoleRedirect
  end

  scope "/", NysSystemWeb do
    pipe_through :browser

    # Public pages
    get "/index", PageController, :index
    get "/logout", AuthController, :logout
    get "/signup", PageController, :signup
    post "/signup", PageController, :create_account
    get "/verify", PageController, :verify
    get "/", PageController, :login
  end

  # Protected routes (require authentication + automatic role routing)
  scope "/", NysSystemWeb do
    pipe_through [:browser, :require_auth, :role_redirect]

    # Generic dashboard - will auto-redirect based on role
    get "/dashboard", PageController, :dashboard
    get "/profile", UserController, :profile

    # Pass application routes (all authenticated users)
    get "/passes/new", PassController, :new
    post "/passes", PassController, :create
  end

  # OC-only routes
  scope "/oc", NysSystemWeb do
    pipe_through [:browser, :require_auth, :require_oc]

    get "/", OCController, :index

    # ADD THESE TWO LINES:
    post "/pass-period/activate", OCController, :activate_pass_period
    post "/pass-period/deactivate", OCController, :deactivate_pass_period

    post "/passes/:id/approve", OCController, :approve_pass
    post "/passes/:id/reject", OCController, :reject_pass
  end

  # Commander-only routes
  scope "/commander", NysSystemWeb do
    pipe_through [:browser, :require_auth, :require_commander]

    get "/", CommanderController, :index
    get "/members/:id", CommanderController, :member_details
    post "/passes/:id/approve", CommanderController, :approve_pass
    post "/passes/:id/reject", CommanderController, :reject_pass
    get "/passes/:id", CommanderController, :show_pass
  end

  # Admin-only routes (User management)
  scope "/", NysSystemWeb do
    pipe_through [:browser, :require_auth, :require_admin]

    resources "/users", UserController, except: [:delete]
  end

  # API routes
  scope "/api", NysSystemWeb do
    pipe_through :api

    # Public API
    post "/auth/login", AuthController, :login
    post "/auth/signup", AuthController, :signup
  end

  # Protected API routes
  scope "/api", NysSystemWeb do
    pipe_through [:api, :require_auth]

    resources "/users", UserController, only: [:index, :show, :create, :update]
    resources "/passes", PassController, only: [:index, :show]
    get "/passes/verify/:pass_number", PassController, :show
    post "/passes/:id/submit", PassController, :submit
    post "/passes/:id/approve", PassController, :approve
    post "/passes/:id/reject", PassController, :reject
    post "/pass_periods/activate", PassPeriodController, :activate
    resources "/inventory", InventoryController, only: [:index, :create, :update, :delete]
    resources "/reports", ReportController, only: [:index, :create]
  end

  # ============================================
  # HELPER PLUGS
  # ============================================

  defp check_authenticated(conn, _opts) do
    if NysSystemWeb.Auth.authenticated?(conn) do
      conn
    else
      conn
      |> Phoenix.Controller.put_view(html: NysSystemWeb.ErrorHTML, json: NysSystemWeb.ErrorJSON)
      |> Plug.Conn.put_status(:unauthorized)
      |> case do
        conn ->
          case conn.private.phoenix_format do
            "json" ->
              Phoenix.Controller.json(conn, %{error: "Authentication required"})

            _ ->
              conn
              |> Phoenix.Controller.put_flash(:error, "You must be logged in to view that page.")
              |> Phoenix.Controller.redirect(to: "/login")
          end
      end
      |> halt()
    end
  end

  defp check_admin(conn, _opts) do
    user = NysSystemWeb.Auth.current_user(conn)

    if user && user.role in ["company_commander", "oc"] do
      conn
    else
      conn
      |> Phoenix.Controller.put_flash(:error, "Admin access required")
      |> Phoenix.Controller.redirect(to: "/dashboard")
      |> halt()
    end
  end

  defp require_commander_role(conn, _opts) do
    user = NysSystemWeb.Auth.current_user(conn)

    if user && user.role == "company_commander" do
      conn
    else
      conn
      |> Phoenix.Controller.put_flash(:error, "Access denied: Company Commander role required")
      |> Phoenix.Controller.redirect(to: "/dashboard")
      |> halt()
    end
  end

  defp require_oc_role(conn, _opts) do
    user = NysSystemWeb.Auth.current_user(conn)

    if user && user.role == "oc" do
      conn
    else
      conn
      |> Phoenix.Controller.put_flash(:error, "Access denied: OC role required")
      |> Phoenix.Controller.redirect(to: "/dashboard")
      |> halt()
    end
  end
end
