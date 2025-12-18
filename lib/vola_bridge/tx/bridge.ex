defmodule VolaBridge.Tx.Bridge do
  @moduledoc """
    Bridge related transaction functions
  """

  alias Sutra.Cardano.Address
  alias VolaBridge.Types.FingerprintDatum
  alias VolaBridge.Types.WithdrawSignatures
  alias Sutra.Cardano.Common.Drep
  alias Sutra.Data
  alias VolaBridge.Types.CertificateDatum
  alias Sutra.Cardano.Address
  alias Sutra.Cardano.Transaction.Output
  alias Sutra.Cardano.Transaction.Input
  alias VolaBridge.BridgeScript.ScriptInfo
  alias VolaBridge.Types
  alias VolaBridge.Types.BridgeDatum
  alias VolaBridge.Certificate

  alias Sutra.Cardano.Transaction.TxBuilder

  @type pubkey() :: binary()
  @type signature() :: binary()
  @type certificate_datum_hash() :: String.t()
  @type fingerprint() :: %{certificate_datum_hash() => [{pubkey(), signature()}]}

  defp fetch_bridge_script(%Input{
         output: %Output{address: %Address{payment_credential: cred}}
       }),
       do: VolaBridge.BridgeScript.bridge_validator_script(cred.hash)

  def place_bridge(
        %Input{} = settings_input,
        bridge_datum = %BridgeDatum{},
        vola_token_policy_id,
        vola_token_asset_name
      ) do
    bridge_script_info =
      %ScriptInfo{} = fetch_bridge_script(settings_input)

    out_assets = %{
      bridge_script_info.script_hash => %{bridge_script_info.asset_name => 1},
      vola_token_policy_id => %{vola_token_asset_name => bridge_datum.amount}
    }

    TxBuilder.new_tx()
    |> TxBuilder.add_reference_inputs([settings_input])
    |> TxBuilder.mint_asset(
      bridge_script_info.script_hash,
      %{bridge_script_info.asset_name => 1},
      bridge_script_info.script,
      Types.deposit_to_bridge_redeemer()
    )
    |> TxBuilder.add_output(
      Sutra.Cardano.Address.from_script(
        bridge_script_info.script_hash,
        VolaBridgeTx.network()
      ),
      out_assets,
      {:inline_datum, bridge_datum}
    )
  end

  @spec withdraw_from_bridge(
          settings_input :: %Input{},
          bridge_inputs :: [%Input{}],
          certificates :: [%CertificateDatum{}],
          cert_inputs :: [%Input{}],
          fingerprints :: fingerprint(),
          vola_token_policy_id :: String.t(),
          vola_token_asset_name :: String.t(),
          signer_address :: %Address{}
        ) :: {:ok, %TxBuilder{}} | {:error, String.t()}
  def withdraw_from_bridge(
        %Input{} = settings_input,
        [%Input{} | _] = bridge_inputs,
        [%CertificateDatum{} | _] = certificates,
        [%Input{} | _] = cert_inputs,
        fingerprints,
        vola_token_policy_id,
        vola_token_asset_name,
        signer_address = %Address{}
      ) do
    bridge_script_info =
      %ScriptInfo{} = fetch_bridge_script(settings_input)

    {change_amt, required_inputs} =
      Certificate.calc_total_bridge_inputs(
        bridge_inputs,
        certificates,
        vola_token_policy_id,
        vola_token_asset_name
      )

    withdraw_redeemer =
      Certificate.prepare_withdraw_signatures(certificates, fingerprints)

    fingerprint_datums =
      Certificate.prepare_fingerprint_datums(fingerprints)
      |> Enum.map(&FingerprintDatum.to_plutus/1)

    initial_tx =
      TxBuilder.new_tx()
      |> TxBuilder.add_input(cert_inputs)
      |> prepare_outputs(certificates, vola_token_policy_id, vola_token_asset_name)

    with {:ok, tx} <-
           maybe_prepare_change(
             initial_tx,
             change_amt,
             vola_token_policy_id,
             vola_token_asset_name,
             bridge_script_info
           ) do
      tx
      |> TxBuilder.add_reference_inputs([settings_input])
      |> TxBuilder.add_input(required_inputs,
        redeemer: Types.redeeem_from_bridge_redeemer(),
        witness: bridge_script_info.script
      )
      |> maybe_burn_token(bridge_script_info, required_inputs, change_amt)
      |> attach_datums(certificates, signer_address)
      |> attach_datums(fingerprint_datums, signer_address)
      |> TxBuilder.withdraw_stake(
        bridge_script_info.script,
        WithdrawSignatures.to_plutus(withdraw_redeemer),
        0
      )
      |> TxBuilder.valid_to(Enum.min(Enum.map(certificates, & &1.invalid_after)))
    end
  end

  defp prepare_outputs(
         tx_builder,
         [%CertificateDatum{} | _] = certificates,
         vola_token_policy_id,
         vola_token_asset_name
       ) do
    Enum.reduce(certificates, tx_builder, fn %CertificateDatum{} = certificate, acc_tx_builder ->
      TxBuilder.add_output(
        acc_tx_builder,
        certificate.receiver_address,
        %{
          vola_token_policy_id => %{
            vola_token_asset_name => certificate.amount
          }
        }
      )
    end)
  end

  defp attach_datums(tx_builder, datums, addr) do
    Enum.reduce(datums, tx_builder, fn datum, acc_tx_builder ->
      acc_tx_builder
      |> TxBuilder.add_output(addr, %{}, {:datum_hash, datum})
    end)
  end

  defp maybe_prepare_change(
         tx,
         change_amt,
         _vola_token_policy_id,
         _vola_token_asset_name,
         _bridge_script_info
       )
       when change_amt == 0, do: {:ok, tx}

  defp maybe_prepare_change(
         tx,
         change_amt,
         vola_token_policy_id,
         vola_token_asset_name,
         bridge_script_info
       )
       when change_amt < 0 do
    out_assets = %{
      vola_token_policy_id => %{vola_token_asset_name => abs(change_amt)},
      bridge_script_info.script_hash => %{bridge_script_info.asset_name => 1}
    }

    new_tx =
      tx
      |> TxBuilder.add_output(
        Sutra.Cardano.Address.from_script(
          bridge_script_info.script_hash,
          VolaBridgeTx.network()
        ),
        out_assets
      )

    {:ok, new_tx}
  end

  defp maybe_prepare_change(
         _tx,
         change_amt,
         _vola_token_policy_id,
         _vola_token_asset_name,
         _bridge_script_info
       ),
       do: {:error, "Cannot fullfill #{abs(change_amt)} from Bridge Inputs"}

  defp maybe_burn_token(tx_builder, bridge_script_info = %ScriptInfo{}, inputs, change_amt)
       when is_integer(change_amt) do
    burn_qty = if change_amt == 0, do: length(inputs), else: length(inputs) - 1

    if burn_qty > 0 do
      TxBuilder.mint_asset(
        tx_builder,
        bridge_script_info.script_hash,
        %{bridge_script_info.asset_name => -burn_qty},
        bridge_script_info.script,
        Types.redeeem_from_bridge_redeemer()
      )
    else
      tx_builder
    end
  end

  def register_stake_credential(%Input{} = settings_input, pool_id, drep \\ Drep.abstain()) do
    bridge_script_info =
      %ScriptInfo{} = fetch_bridge_script(settings_input)

    TxBuilder.new_tx()
    |> TxBuilder.delegate_stake_and_vote(bridge_script_info.script, drep, pool_id, Data.void())
  end
end
