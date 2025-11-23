defmodule NysSystemWeb.PassHTML do
  @moduledoc """
  This module contains pages rendered by PassController.
  """
  use NysSystemWeb, :html

  embed_templates "pass_html/*"
end
