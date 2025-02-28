defmodule Nostr.Event.Types.EncryptedDirectMessageEvent do
  @moduledoc """
  Encrypted direct message event management, including event creation and parsing
  """

  require Logger

  defstruct [:decrypted, :decryption_error, event: %Nostr.Event{}]

  alias Nostr.Event
  alias Nostr.Event.Types.EncryptedDirectMessageEvent
  alias Nostr.Keys.PublicKey

  @type t :: %EncryptedDirectMessageEvent{}

  @kind 4

  @spec create(String.t() | nil, <<_::256>>, <<_::256>>) :: EncryptedDirectMessageEvent.t()
  def create(content, local_pubkey, remote_pubkey) do
    hex_pubkey = PublicKey.to_hex(remote_pubkey)

    tags = [["p", hex_pubkey]]

    event =
      %{Event.create(content, local_pubkey) | kind: @kind, tags: tags}
      |> Event.add_id()

    %EncryptedDirectMessageEvent{event: event}
  end

  def parse(%{"content" => content} = body) do
    event = %{Event.parse(body) | content: content}

    case event.kind do
      @kind ->
        {:ok, %EncryptedDirectMessageEvent{event: event}}

      kind ->
        {:error,
         "Tried to parse a encrypted direct message event with kind #{kind} instead of #{@kind}"}
    end
  end
end
