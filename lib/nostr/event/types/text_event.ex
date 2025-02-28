defmodule Nostr.Event.Types.TextEvent do
  @moduledoc """
  Text event management, including event creation and parsing

  Represents messages sent through the nostr protocol intented for display in clients
  """

  require Logger

  defstruct event: %Nostr.Event{}

  alias Nostr.Event
  alias Nostr.Event.Types.TextEvent

  @type t :: %TextEvent{}

  @kind 1

  @spec create(binary(), <<_::256>>) :: TextEvent.t()
  def create(content, pubkey) do
    event =
      %{Event.create(content, pubkey) | kind: @kind}
      |> Event.add_id()

    %TextEvent{event: event}
  end

  def parse(%{"content" => content} = body) do
    event = %{Event.parse(body) | content: content}

    case event.kind do
      @kind -> {:ok, %TextEvent{event: event}}
      kind -> {:error, "Tried to parse a text event with kind #{kind} instead of #{@kind}"}
    end
  end
end
