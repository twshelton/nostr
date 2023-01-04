defmodule Nostr.Client do
  @moduledoc """
  Connects to a relay through websockets
  """

  require Logger

  alias Nostr.Event.{Signer, Validator}
  alias Nostr.Event.Types.{TextEvent}
  alias Nostr.Client.{SendRequest}
  alias Nostr.Client.Requests.{SubscribeRequest, Contacts, Profile}
  alias K256.Schnorr

  @default_relay "wss://relay.nostr.pro"
  @default_config {}

  @doc """
  Starts the client

  ## Examples
    iex> Nostr.Client.start_link("wss://relay.nostr.pro")
  """
  @spec start_link(String.t(), tuple()) :: {:ok, pid()} | {:error, binary()}
  def start_link(relay_url \\ @default_relay, config \\ @default_config) do
    WebSockex.start_link(
      relay_url,
      Nostr.Client.Server,
      %{client_pid: self(), config: config}
    )
  end

  @doc """
  Subscribes to an author's events
  """
  @spec subscribe_author(pid(), <<_::256>>, integer()) :: binary()
  def subscribe_author(pid, pubkey, max_messages \\ 100) do
    {request_id, request} = SubscribeRequest.author(pubkey, max_messages)

    WebSockex.cast(pid, {:send_message, request})

    request_id
  end

  @doc """
  Get an author's contacts
  """
  @spec get_contacts(pid(), <<_::256>>) :: binary()
  def get_contacts(pid, pubkey) do
    {request_id, request} = Contacts.get(pubkey)

    WebSockex.cast(pid, {:send_message, request})

    request_id
  end

  @doc """
  Get an author's profile
  """
  @spec get_profile(pid(), <<_::256>>) :: binary()
  def get_profile(pid, pubkey) do
    {request_id, request} = Profile.get(pubkey)

    WebSockex.cast(pid, {:send_message, request})

    request_id
  end

  @doc """
  Sends a note to the relay
  """
  @spec send_note(pid(), String.t(), K256.Schnorr.signing_key()) ::
          :ok | {:error, binary() | atom()}
  def send_note(pid, note, privkey) do
    with {:ok, pubkey} <- Schnorr.verifying_key_from_signing_key(privkey),
         text_event = TextEvent.create(note, pubkey),
         {:ok, signed_event} <- Signer.sign_event(text_event.event, privkey),
         :ok <- Validator.validate_event(signed_event) do
      request = SendRequest.event(signed_event)

      WebSockex.cast(pid, {:send_message, request})
    else
      {:error, message} -> {:error, message}
    end
  end
end
