defmodule RetWeb.Api.V1.HubController do
  use RetWeb, :controller

  import Canary.Plugs

  alias Ret.{Hub, Scene, Repo}

  # Limit to 1 TPS
  plug(RetWeb.Plugs.RateLimit)

  # Only allow access with secret header
  plug(RetWeb.Plugs.HeaderAuthorization when action in [:delete])

  plug(:authorize_resource, model: Hub, id_field: "hub_sid", only: [:update])

  def update(conn, %{"id" => hub_sid, "hub" => params}) do
    hub = Hub |> Repo.get_by(hub_sid: hub_sid)

    case hub do
      %Hub{} = hub ->
        hub
        |> Hub.changeset_for_new_name(params)
        |> Repo.update()

        conn |> render("create.json", hub: hub)

      _ ->
        conn |> send_resp(404, "not found")
    end
  end

  def create(conn, %{"hub" => %{"scene_id" => scene_id}} = params) do
    scene = Scene |> Repo.get_by(scene_sid: scene_id)

    %Hub{}
    |> Hub.changeset(scene, params["hub"])
    |> exec_create(conn)
  end

  def create(conn, %{"hub" => _hub_params} = params) do
    %Hub{}
    |> Hub.changeset(nil, params["hub"])
    |> exec_create(conn)
  end

  defp exec_create(hub_changeset, conn) do
    {result, hub} =
      hub_changeset
      |> Hub.add_account_to_changeset(Guardian.Plug.current_resource(conn))
      |> Repo.insert()

    case result do
      :ok -> render(conn, "create.json", hub: hub)
      :error -> conn |> send_resp(422, "invalid hub")
    end
  end

  def delete(conn, %{"id" => hub_sid}) do
    Hub
    |> Repo.get_by(hub_sid: hub_sid)
    |> Hub.changeset_to_deny_entry()
    |> Repo.update!()

    conn |> send_resp(200, "OK")
  end
end

defimpl Canada.Can, for: Ret.Account do
  def can?(%Ret.Account{account_id: account_id}, :update, %Ret.Hub{account_id: account_id}), do: true
  def can?(_, _, _), do: false
end
