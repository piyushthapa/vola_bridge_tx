defmodule VolaBridge.Tx.Settings do
  @moduledoc """
    Settings related transaction functions
  """

  alias Sutra.Cardano.Transaction.Input
  alias VolaBridge.Types.SettingsDatum
  alias Sutra.Cardano.Address
  alias Sutra.Data
  alias VolaBridge.BridgeScript.ScriptInfo
  alias VolaBridge.BridgeScript

  import Sutra.Cardano.Transaction.TxBuilder

  def create_settings_tx(utxo_input = %Input{}) do
    settings_script_info =
      %ScriptInfo{} = BridgeScript.settings_validator_script(utxo_input.output_reference)

    bridge_script_info =
      %ScriptInfo{} = BridgeScript.bridge_validator_script(settings_script_info.script_hash)

    vola_token_info = %ScriptInfo{} = BridgeScript.vola_token_validaor()
    signers = VolaBridgeTx.signers_pubkey_hash()

    settings_datum = %SettingsDatum{
      signers: signers,
      bridge_policy_id: bridge_script_info.script_hash,
      vola_token_policy_id: vola_token_info.script_hash,
      vola_token_asset_name: vola_token_info.asset_name,
      required_signers_count: div(length(signers), 2) + 1
    }

    new_tx()
    |> add_input([utxo_input])
    |> mint_asset(
      settings_script_info.script_hash,
      %{settings_script_info.asset_name => 1},
      settings_script_info.script,
      Data.void()
    )
    |> add_output(
      Address.from_script(
        settings_script_info.script_hash,
        VolaBridgeTx.network()
      ),
      %{settings_script_info.script_hash => %{settings_script_info.asset_name => 1}},
      {:inline_datum, settings_datum}
    )
  end
end
