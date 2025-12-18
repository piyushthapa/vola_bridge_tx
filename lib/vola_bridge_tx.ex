defmodule VolaBridgeTx do
  @moduledoc """
  Documentation for `VolaBridgeTx`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> VolaBridgeTx.hello()
      :world

  """
  def hello do
    :world
  end

  def network do
    Application.get_env(:vola_bridge_tx, :cardano_network, :testnet)
  end

  def signers_pubkey_hash do
    Application.get_env(:vola_bridge_tx, :signers, [])
  end
end
