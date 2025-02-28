defmodule Nostr.Client.Subscriptions.EncryptedDirectMessagesSubscription do
  @moduledoc """
  A process creating and managing a live subscription to a user's encrypted
  direct messages on a bunch of relays
  """

  use GenServer

  alias Nostr.Client.Relays.RelaySocket
  alias Nostr.Event
  alias Nostr.Event.Types.{EncryptedDirectMessageEvent, EndOfStoredEvents}
  alias Nostr.Keys.PublicKey
  alias Nostr.Crypto.AES256CBC

  def start_link([relay_pids, private_key, subscriber]) do
    GenServer.start_link(__MODULE__, %{
      relay_pids: relay_pids,
      private_key: private_key,
      subscriber: subscriber
    })
  end

  @impl true
  def init(%{relay_pids: relay_pids, private_key: private_key} = state) do
    case PublicKey.from_private_key(private_key) do
      {:ok, public_key} ->
        subscriptions =
          relay_pids
          |> Enum.map(fn relay_pid ->
            RelaySocket.subscribe_encrypted_direct_messages(relay_pid, public_key)
          end)

        {
          :ok,
          state
          |> Map.put(:public_key, public_key)
          |> set_encrypted_direct_messages_subscriptions(subscriptions)
        }

      {:error, message} ->
        {:stop, {:shutdown, message}}
    end
  end

  @impl true
  def handle_info(
        {_relay_url,
         %EncryptedDirectMessageEvent{
           event: %Event{pubkey: remote_pubkey, content: encrypted_content}
         } = encrypted_dm},
        %{subscriber: subscriber, private_key: local_private_key} = state
      ) do
    case AES256CBC.decrypt(encrypted_content, local_private_key, remote_pubkey) do
      {:ok, decrypted} ->
        send(subscriber, %{encrypted_dm | decrypted: decrypted})

      {:error, message} ->
        send(subscriber, %{encrypted_dm | decryption_error: message})
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({_relay_url, %EndOfStoredEvents{}}, state) do
    ## nothing to do

    {:noreply, state}
  end

  defp set_encrypted_direct_messages_subscriptions(state, subscriptions) do
    Map.put(state, :subscriptions, subscriptions)
  end
end
