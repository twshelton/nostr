defmodule Nostr.Client.Workflows.Unfollow do
  @moduledoc """
  A process that's responsible to subscribe and listen to relays so
  it can properly enable a user's to unfollow a current contact
  """

  #### TODO: make sure to have the latest contact list before upgrading it
  ####       right now, we update the first contact list that we receive
  ####       and it might not be the latest...
  ####       maybe will have to make sure we connect to the relay list from
  ####       the user's metadata, get all contact lists, and pick the latest

  use GenServer

  alias Nostr.Client.Relays.RelaySocket
  alias Nostr.Event.{Signer, Validator}
  alias Nostr.Event.Types.{ContactsEvent, EndOfStoredEvents}
  alias Nostr.Models.ContactList
  alias Nostr.Keys.PublicKey

  def start_link(relay_pids, unfollow_pubkey, privkey) do
    GenServer.start(__MODULE__, %{
      relay_pids: relay_pids,
      privkey: privkey,
      unfollow_pubkey: unfollow_pubkey
    })
  end

  @impl true
  def init(%{relay_pids: relay_pids, privkey: privkey} = state) do
    case PublicKey.from_private_key(privkey) do
      {:ok, pubkey} ->
        subscriptions = subscribe_contacts(relay_pids, pubkey)

        {
          :ok,
          state
          |> Map.put(:subscriptions, subscriptions)
          |> Map.put(:treated, false)
        }

      {:error, message} ->
        {:stop, {:shutdown, message}}
    end
  end

  def handle_info(:unsubscribe_contacts, %{subscriptions: subscriptions} = state) do
    unsubscribe_contacts(subscriptions)

    {
      :noreply,
      state
      |> Map.put(:subscriptions, [])
    }
  end

  def handle_info(
        {:unfollow, contacts},
        %{privkey: privkey, relay_pids: relay_pids, unfollow_pubkey: unfollow_pubkey} = state
      ) do
    unfollow(unfollow_pubkey, privkey, contacts, relay_pids)

    {:noreply, state}
  end

  @impl true
  def handle_info({_relay, %EndOfStoredEvents{}}, %{privkey: privkey, treated: false} = state) do
    profile_pubkey = Nostr.Keys.PublicKey.from_private_key!(privkey)

    new_contact_list = %Nostr.Models.ContactList{
      pubkey: profile_pubkey,
      created_at: DateTime.utc_now(),
      contacts: []
    }

    send(self(), {:unfollow, new_contact_list})

    {
      :noreply,
      state
      |> Map.put(:treated, true)
    }
  end

  @impl true
  # when we first get the contacts, time to add a new pubkey on it
  def handle_info({_relay, contacts}, %{treated: false} = state) do
    send(self(), {:unfollow, contacts})
    send(self(), :unsubscribe_contacts)

    {
      :noreply,
      state
      |> Map.put(:treated, true)
    }
  end

  @impl true
  # when the unfollow has already been executed
  def handle_info({_relay, _contacts}, %{treated: true} = state) do
    {:noreply, state}
  end

  defp subscribe_contacts(relay_pids, pubkey) do
    relay_pids
    |> Enum.map(fn relay_pid ->
      subscription_id = RelaySocket.subscribe_contacts(relay_pid, pubkey)

      {relay_pid, subscription_id}
    end)
  end

  defp unsubscribe_contacts(subscriptions) do
    for {relaysocket_pid, subscription_id} <- subscriptions do
      RelaySocket.unsubscribe(relaysocket_pid, subscription_id)
    end
  end

  defp unfollow(unfollow_pubkey, privkey, contact_list, relay_pids) do
    contact_list = ContactList.remove(contact_list, unfollow_pubkey)

    {:ok, signed_event} =
      contact_list
      |> ContactsEvent.create_event()
      |> Signer.sign_event(privkey)

    :ok = Validator.validate_event(signed_event)

    for relay_pid <- relay_pids do
      RelaySocket.send_event(relay_pid, signed_event)
    end
  end
end
