defmodule VolaBridge.Types do
  @moduledoc """
    Datums and redeemers used in Vola Bridge contracts.


  """

  alias Sutra.Cardano.Address
  alias Sutra.Data.Plutus.Constr
  alias Sutra.Cardano.Transaction.OutputReference

  use Sutra.Data

  defdata(name: SettingsDatum) do
    data(:bridge_policy_id, :string)
    data(:signers, [:string])
    data(:vola_token_policy_id, :string)
    data(:vola_token_asset_name, :string)
    data(:required_signers_count, :integer)
  end

  defdata(name: CertificateDatum) do
    data(:utxo, OutputReference)
    data(:invalid_after, :integer)
    data(:amount, :integer)
    data(:vola_chain_tx_id, :string)
    data(:receiver_address, Address)
  end

  defdata(name: BridgeDatum) do
    data(:amount, :integer)
    data(:receiver_address, :string)
    data(:created_at, :integer)
  end

  # from Aiken
  # pub type WithdrawSignatures = List<(DataHash, DataHash)>
  deftype(name: WithdrawSignatures, type: [{:bytes, :bytes}])

  # from Aiken
  # pub type FingerprintDatum = List<(PubKey, Signature)>
  deftype(name: FingerprintDatum, type: [{:bytes, :bytes}])

  def deposit_to_bridge_redeemer() do
    %Constr{index: 0, fields: []}
  end

  def redeeem_from_bridge_redeemer() do
    %Constr{index: 1, fields: []}
  end

  def withdraw_signature_redeemer(signatures) when is_list(signatures) do
    %Constr{index: 0, fields: [signatures]}
  end
end
