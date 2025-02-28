defmodule Nostr.Models.ContactList do
  @moduledoc """
  Represents a nostr user's contact list
  """

  defstruct [:id, :pubkey, :created_at, :contacts]

  alias Nostr.Models.{Contact, ContactList}

  def add(%ContactList{contacts: contacts} = contact_list, pubkey) do
    contact = %Contact{pubkey: pubkey}

    new_contacts = [contact | contacts]

    %{contact_list | contacts: new_contacts}
  end

  def remove(%ContactList{contacts: contacts} = contact_list, pubkey_to_remove) do
    new_contacts =
      contacts
      |> Enum.filter(fn %Contact{pubkey: contact_pubkey} ->
        pubkey_to_remove != contact_pubkey
      end)

    %{contact_list | contacts: new_contacts}
  end
end
